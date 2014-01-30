#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include "StdDmaIndication.h"

#include "DmaConfigProxy.h"
#include "GeneratedTypes.h" 
#include "Memread2IndicationWrapper.h"
#include "Memread2RequestProxy.h"

PortalAlloc *srcAlloc, *srcAlloc2;
unsigned int *srcBuffer = 0;
unsigned int *srcBuffer2 = 0;
int numWords = 16 << 8;
size_t test_sz  = numWords*sizeof(unsigned int);
size_t alloc_sz = test_sz;

void dump(const char *prefix, char *buf, size_t len)
{
    fprintf(stderr, "%s ", prefix);
    for (int i = 0; i < (len > 16 ? 16 : len) ; i++)
	fprintf(stderr, "%02x", (unsigned char)buf[i]);
    fprintf(stderr, "\n");
}

class Memread2Indication : public Memread2IndicationWrapper
{
public:
  unsigned int rDataCnt;
  virtual void readReq(unsigned long v){
    //fprintf(stderr, "Memread2::readReq %lx\n", v);
  }
  virtual void readDone(unsigned long v){
    fprintf(stderr, "Memread2::readDone mismatch=%lx\n", v);
    mismatchCount = v;
    if (mismatchesReceived == mismatchCount)
      exit(v ? 1 : 0);
  }
  virtual void started(unsigned long words){
    fprintf(stderr, "Memread2::started: words=%lx\n", words);
  }
  virtual void rData ( unsigned long long v ){
    fprintf(stderr, "rData (%08x): ", rDataCnt++);
    dump("", (char*)&v, sizeof(v));
  }
  virtual void reportStateDbg(unsigned long streamRdCnt, unsigned long dataMismatch){
    fprintf(stderr, "Memread2::reportStateDbg: streamRdCnt=%08lx dataMismatch=%ld\n", streamRdCnt, dataMismatch);
  }  
  virtual void mismatch(unsigned long offset, unsigned long long ev, unsigned long long v) {
    fprintf(stderr, "Mismatch at %lx %llx != %llx\n", offset, ev, v);

    mismatchesReceived++;
    if (mismatchesReceived == mismatchCount)
      exit(1);
  }

  Memread2Indication(const char* devname, unsigned int addrbits) : Memread2IndicationWrapper(devname,addrbits), mismatchCount(0), mismatchesReceived(0){}
private:
  int mismatchCount;
  int mismatchesReceived;
};

int main(int argc, const char **argv)
{
  unsigned int srcGen = 0;

  Memread2RequestProxy *device = 0;
  DmaConfigProxy *dma = 0;
  
  Memread2Indication *deviceIndication = 0;
  DmaIndication *dmaIndication = 0;

  fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);

  device = new Memread2RequestProxy("fpga1", 16);
  dma = new DmaConfigProxy("fpga3", 16);

  deviceIndication = new Memread2Indication("fpga2", 16);
  dmaIndication = new DmaIndication(dma, "fpga4", 16);

  fprintf(stderr, "Main::allocating memory...\n");
  dma->alloc(alloc_sz, &srcAlloc);
  srcBuffer = (unsigned int *)mmap(0, alloc_sz, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, srcAlloc->header.fd, 0);
  dma->alloc(alloc_sz, &srcAlloc2);
  srcBuffer2 = (unsigned int *)mmap(0, alloc_sz, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, srcAlloc2->header.fd, 0);

  pthread_t tid;
  fprintf(stderr, "Main::creating exec thread\n");
  if(pthread_create(&tid, NULL,  portalExec, NULL)){
   fprintf(stderr, "error creating exec thread\n");
   exit(1);
  }

  for (int i = 0; i < numWords; i++){
    int v = srcGen++;
    srcBuffer[i] = v;
    srcBuffer2[i] = v * 3;;
  }
    
  dma->dCacheFlushInval(srcAlloc, srcBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");

  unsigned int ref_srcAlloc = dma->reference(srcAlloc);
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
  unsigned int ref_srcAlloc2 = dma->reference(srcAlloc2);
  fprintf(stderr, "ref_srcAlloc2=%d\n", ref_srcAlloc2);

  fprintf(stderr, "Main::starting read %08x\n", numWords);
  device->startRead(ref_srcAlloc, ref_srcAlloc2, 128, 1);

  device->getStateDbg();
  fprintf(stderr, "Main::sleeping\n");
  while(true){sleep(1);}
}

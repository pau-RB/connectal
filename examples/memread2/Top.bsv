// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import DmaUtils::*;
import AxiDma::*;

// generated by tool
import Memread2RequestWrapper::*;
import DmaConfigWrapper::*;
import Memread2IndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memread2::*;

module mkPortalTop(StdPortalDmaTop#(addrWidth)) provisos (
    Add#(addrWidth, a__, 52),
    Add#(b__, addrWidth, 64),
    Add#(c__, 12, addrWidth),
    Add#(addrWidth, d__, 44));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(9);

   Memread2IndicationProxy memreadIndicationProxy <- mkMemread2IndicationProxy(7);
   Memread2 memread <- mkMemread2(memreadIndicationProxy.ifc);
   Memread2RequestWrapper memreadRequestWrapper <- mkMemread2RequestWrapper(1008,memread.request);

   Vector#(2, DmaReadClient#(64)) clients;
   Bool buffered = True;
   if (buffered) begin
      Vector#(2, DmaReadBuffer#(64, 16)) readBuffers <- replicateM(mkDmaReadBuffer);
      mkConnection(memread.dmaClient, readBuffers[0].dmaServer);
      mkConnection(memread.dmaClient2, readBuffers[1].dmaServer);
      clients = cons(readBuffers[0].dmaClient, cons(readBuffers[1].dmaClient, nil));
   end
   else begin
      clients = cons(memread.dmaClient, cons(memread.dmaClient2, nil));
   end

   Integer             numRequests = 2;
   AxiDmaServer#(addrWidth,64) dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, clients, nil);

   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(1005,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = memreadRequestWrapper.portalIfc;
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = replicate(dma.m_axi);
   interface leds = ?;
endmodule : mkPortalTop

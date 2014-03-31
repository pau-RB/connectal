// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


import BRAM::*;
import FIFO::*;
import Vector::*;
import Gearbox::*;
import FIFOF::*;
import SpecialFIFOs::*;

import BRAMFIFOFLevel::*;
import GetPut::*;
import Dma::*;

//
// @brief A buffer for reading from a bus of width bsz.
//
// @param bsz The number of bits in the bus.
// @param bufferDepth The depth of the internal buffer
//
interface DmaReadBuffer#(numeric type bsz, numeric type bufferDepth);
   interface ObjectReadServer #(bsz) dmaServer;
   interface ObjectReadClient#(bsz) dmaClient;
endinterface

//
// @brief A buffer for writing to a bus of width bsz.
//
// @param bsz The number of bits in the bus.
// @param bufferDepth The depth of the internal buffer
//
interface DmaWriteBuffer#(numeric type bsz, numeric type bufferDepth);
   interface ObjectWriteServer#(bsz) dmaServer;
   interface ObjectWriteClient#(bsz) dmaClient;
endinterface

//
// @brief Makes a Dma buffer for reading wordSize words from memory.
//
// @param bsz The width of the bus in bits.
// @param bufferDepth The depth of the internal buffer
//
module mkDmaReadBuffer(DmaReadBuffer#(bsz, bufferDepth))
   provisos(Add#(1,a__,bsz),
	    Add#(b__, TAdd#(1,TLog#(bufferDepth)), 8));

   FIFOFLevel#(ObjectData#(bsz),bufferDepth)  readBuffer <- mkBRAMFIFOFLevel;
   FIFOF#(ObjectRequest)        reqOutstanding <- mkFIFOF();
   Ratchet#(TAdd#(1,TLog#(bufferDepth))) unfulfilled <- mkRatchet(0);
   
   // only issue the readRequest when sufficient buffering is available.  This includes the bufering we have already comitted.
   Bit#(TAdd#(1,TLog#(bufferDepth))) sreq = pack(satPlus(Sat_Bound, unpack(truncate(reqOutstanding.first.burstLen)), unfulfilled.read()));

   interface ObjectReadServer dmaServer;
      interface Put readReq = toPut(reqOutstanding);
      interface Get readData = toGet(readBuffer);
   endinterface
   interface ObjectReadClient dmaClient;
      interface Get readReq;
	 method ActionValue#(ObjectRequest) get if (readBuffer.lowWater(sreq));
	    reqOutstanding.deq;
	    unfulfilled.increment(unpack(truncate(reqOutstanding.first.burstLen)));
	    return reqOutstanding.first;
	 endmethod
      endinterface
      interface Put readData;
	 method Action put(ObjectData#(bsz) x);
	    readBuffer.fifo.enq(x);
	    unfulfilled.decrement(1);
	 endmethod
      endinterface
   endinterface
endmodule

//
// @brief Makes a Dma channel for writing wordSize words from memory.
//
// @param bsz The width of the bus in bits.
// @param bufferDepth The depth of the internal buffer
//
module mkDmaWriteBuffer(DmaWriteBuffer#(bsz, bufferDepth))
   provisos(Add#(1,a__,bsz),
	    Add#(b__, TAdd#(1, TLog#(bufferDepth)), 8));

   FIFOFLevel#(ObjectData#(bsz),bufferDepth) writeBuffer <- mkBRAMFIFOFLevel;
   FIFOF#(ObjectRequest)        reqOutstanding <- mkFIFOF();
   FIFOF#(Bit#(6))                        doneTags <- mkFIFOF();
   Ratchet#(TAdd#(1,TLog#(bufferDepth)))  unfulfilled <- mkRatchet(0);
   
   // only issue the writeRequest when sufficient data is available.  This includes the data we have already comitted.
   Bit#(TAdd#(1,TLog#(bufferDepth))) sreq = pack(satPlus(Sat_Bound, unpack(truncate(reqOutstanding.first.burstLen)), unfulfilled.read()));

   interface ObjectWriteServer dmaServer;
      interface Put writeReq = toPut(reqOutstanding);
      interface Put writeData = toPut(writeBuffer);
      interface Get writeDone = toGet(doneTags);
   endinterface
   interface ObjectWriteClient dmaClient;
      interface Get writeReq;
	 method ActionValue#(ObjectRequest) get if (writeBuffer.highWater(sreq));
	    reqOutstanding.deq;
	    unfulfilled.increment(unpack(truncate(reqOutstanding.first.burstLen)));
	    return reqOutstanding.first;
	 endmethod
      endinterface
      interface Get writeData;
	 method ActionValue#(ObjectData#(bsz)) get();
	    unfulfilled.decrement(1);
	    writeBuffer.fifo.deq;
	    return writeBuffer.fifo.first;
	 endmethod
      endinterface
      interface Put writeDone = toPut(doneTags);
   endinterface
endmodule

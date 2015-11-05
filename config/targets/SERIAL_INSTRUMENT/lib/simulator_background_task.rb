require 'cosmos/tools/cmd_tlm_server/background_task'

module Cosmos

  # This class is a simulated serial instrument. It sends some fake status over a serial port
  # and accepts commands over serial to modify that fake data.
  # NOTE: This is a demo. There is no error checking. Or good design. Or demonstration of any
  # good software practice. It merely demonstrates reading and writing to a serial port.
  class SimulatorBackgroundTask < BackgroundTask
    
    #TODO: Put these back into the constructor when the background task parameter issue is fixed
    #def initialize(write_port_name, baud_rate, parity, stop_bits, write_timeout, read_timeout)
    def initialize
      super()
      
      #TODO: Put the com port parameters here until the cosmos core is fixed
      port_name = "COM7"
      baud_rate = 128000
      parity = :NONE
      stop_bits = 1
      write_timeout = 1
      
      #Create a status packet that can contain the status of the simulated serial interface
      @status_packet = Structure.new(:BIG_ENDIAN)
      @status_packet.append_item('PKT_LEN', 32, :UINT)
      @status_packet.append_item('PKT_ID', 32, :UINT)
      @status_packet.append_item('SEQ_COUNT', 32, :UINT)
      @status_packet.append_item('CMD_RECV_COUNT', 32, :UINT)
      @status_packet.append_item('DATA_STRING', 400, :STRING)
      @status_packet.append_item('DATA_FLOAT', 64, :FLOAT)
      @status_packet.enable_method_missing
      
      #Set the static elements of the packet to their fixed values
      @status_packet.PKT_ID = 0
      @status_packet.PKT_LEN = @status_packet.length
      
      #Create a serial port with the parameters we received
      @serial_port = SerialDriver.new(port_name,
                                            baud_rate,
                                            parity,
                                            stop_bits,
                                            write_timeout)
    end
    
    # This is the entry point for all background tasks
    def call
      #Create a telemetry generation thread.
      Thread.new do
        while (true)
          #Write the status packet to the serial port
          @serial_port.write(@status_packet.buffer)
          #Approximately 1Hz packet rate
          sleep(1.0)
          #Increment the packet sequence counter
          @status_packet.SEQ_COUNT += 1
        end
      end
      
      #Create a command read thread.
      Thread.new do
        while (true)
          bytesRead = 0
          dataBuff = ''
          
          #Keep reading until we get enough bytes to specify a packet length
          while (bytesRead < 4)
            bytesJustRead = @serial_port.read()
            bytesRead += bytesJustRead.length
            #Shove everything we receive into a buffer
            dataBuff << bytesJustRead
          end
          
          #Now that we know the length we expect, keep reading until we get
          #that many bytes
          while (bytesRead < dataBuff[0..3].unpack("N")[0])
            bytesJustRead = @serial_port.read()
            bytesRead += bytesJustRead.length
            #shove everything we receive into a buffer
            dataBuff << bytesJustRead
          end
          
          #Okay, if everything went well, we are the proud owners of a new command.
          #Go ahead and bust a command ID out of the buffer
          cmdId = dataBuff[4..7].unpack("N")[0]
          
          case cmdId
          # Command ID 0 is to set the string data telemetry
          when 0
            @status_packet.DATA_STRING = dataBuff[8..-1]
            @status_packet.CMD_RECV_COUNT += 1
          # Command ID 1 is to set the floating point data telemetry
          when 1
            @status_packet.DATA_FLOAT = dataBuff[8..-1].unpack("G")[0]
            @status_packet.CMD_RECV_COUNT += 1
          else
            puts "***Bad command: #{dataBuff}"
          end
          
        end #while (true)
      end #Thread.new do
      
    end #def call
  end #class SimulatorBackgroundTask < BackgroundTask

end #module Cosmos

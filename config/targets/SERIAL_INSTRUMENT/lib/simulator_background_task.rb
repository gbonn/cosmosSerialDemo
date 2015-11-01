require 'cosmos/tools/cmd_tlm_server/background_task'

module Cosmos

  class SimulatorBackgroundTask < BackgroundTask
    
    def initialize(write_port_name, baud_rate, parity, stop_bits, write_timeout, read_timeout)
    #def initialize(test)
      super()
      
      @status_packet = Structure.new(:BIG_ENDIAN)
      @status_packet.append_item('DAY', 16, :UINT)
      @status_packet.append_item('MSOD', 32, :UINT)
      @status_packet.append_item('USOMS', 16, :UINT)
      @status_packet.enable_method_missing
      
      @write_serial_port = SerialDriver.new(write_port_name,
                                            baud_rate,
                                            parity,
                                            stop_bits,
                                            write_timeout,
                                            read_timeout)
    end
    
    def call
      while (true)
        @write_serial_port.write(@status_packet)
        sleep(1.0)
      end
    end
  end

end

# Music class loads SID file binary data into memory at $1000
class Music < R64::Base
  def variables
    @current_pc = @processor.pc
    @processor.set_pc 0x1000
    
    # Load SID file and extract the music data (skip SID header)
    sid_file_path = File.join(File.dirname(__FILE__), '..', 'assets', 'photographic.sid')
    sid_file = File.binread(sid_file_path)
    
    # SID header is 0x7C (124) bytes, music data starts after
    # + 2 bytes for C64 file header
    header_size = 0x7E
    music_data = sid_file[header_size..-1]
    
    # Place the music data at $1000
    data :music_data, music_data.bytes
    
    @processor.set_pc @current_pc
  end
end
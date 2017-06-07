require "digest/md5"

module BSON
  struct ObjectId
    include BSON::Value

    getter bytes

    def initialize
      @bytes = @@generator.next_object_id
    end

    def initialize(@bytes : Slice(UInt8))
    end

    def generation_time
      io = IO::Memory.new(bytes[0, 4])
      Time.epoch(Int32.from_bson(io))
    end

    def to_s
      bytes.hexstring
    end

    def inspect(io)
      io << "ObjectId(\"#{to_s}\")"
    end

    def self.from_bson(bson : IO)
      oid = new(Slice(UInt8).new(12))
      bson.read(oid.bytes)
      oid
    end

    def to_bson(bson : IO)
      bson.write(bytes)
    end

    def bson_size
      bytes.size
    end

    def ==(other : ObjectId)
      bytes == other.bytes
    end

    def self.generator
      @@generator
    end

    class Generator
      getter :machine_id, :counter

      def initialize
        @counter = 0
        @machine_id = Digest::MD5.hexdigest(`hostname`)
        @mutex = Mutex.new
      end

      def next_object_id(time = nil)
        @mutex.lock
        begin
          count = @counter = (@counter + 1) % 0xFFFFFF
        ensure
          @mutex.unlock rescue nil
        end
        generate(time || Time.utc_now.epoch, count)
      end

      def generate(time, counter = 0)
        bytes = Slice(UInt8).new(12)
        [0, 1, 2, 3].each { |i| bytes[i] = time.to_i32.to_slice[i] }
        machine_id_slice = Slice(UInt8).new(pointerof(@machine_id).as UInt8*, 3)
        [4, 5, 6].each { |i| bytes[i] = machine_id_slice[i - 4] }
        [7, 8].each { |i| bytes[i] = process_id.to_slice[i - 7] }
        [9, 10, 11].each { |i| bytes[i] = counter.to_slice[i - 9] }
        bytes
      end

      def process_id
        Process.pid % 0xFFFF
      end
    end

    @@generator = Generator.new
  end
end

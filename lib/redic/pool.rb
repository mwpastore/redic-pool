# frozen_string_literal: true
require "connection_pool"
require "redic"

class Redic::Pool
  VERSION = "1.0.1"

  attr :url
  attr :pool

  def initialize(url = "redis://127.0.0.1:6379", timeout = 10_000_000, **opts)
    opts[:size] = 10 unless opts.key?(:size)

    @url = url
    @pool = ConnectionPool.new(opts) { Redic.new(url, timeout) }
    @buffer = Hash.new { |h, k| h[k] = [] }
  end

  def buffer
    @buffer[Thread.current.object_id]
  end

  def reset
    @buffer.delete(Thread.current.object_id)
  end

  def queue(*args)
    buffer << args
  end

  def commit
    @pool.with do |client|
      client.buffer.concat(buffer)
      client.commit
    end
  ensure
    reset
  end

  %w[call call!].each do |method|
    eval <<~STR
      def #{method}(*args)
        pool.with do |client|
          client.#{method}(*args)
        end
      end
    STR
  end
end

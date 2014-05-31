require 'net/http'
require 'net/https'
require 'json'
require 'thread'

module Chain
  @conn_mutex = Mutex.new

  API_URL = URI.parse(ENV['CHAIN_URL'] || raise("Must set CHAIN_URL."))
  CHAIN_PEM = File.expand_path('../chain.pem', __FILE__)
  API_VERSION = 'v1'

  ChainError = Class.new(StandardError)

  def self.get_address(addr)
    get("/#{API_VERSION}/bitcoin/addresses/#{addr}")
  end

  def self.get_unspent_outputs(addr)
    get("/#{API_VERSION}/bitcoin/addresses/#{addr}/unspents")
  end

  def self.send_transactions(hex)
    put("/#{API_VERSION}/bitcoin/transactions", encode_body!({hex: hex}))
  end

  private

  def self.put(path, body)
    conn do |c|
      req = Net::HTTP::Put.new(API_URL.request_uri + path)
      prepare_req!(req)
      req.body = body
      parse_resp(con.request(req))
    end
  end

  def self.get(path)
    conn do |c|
      req = Net::HTTP::Get.new(API_URL.request_uri + path)
      prepare_req!(req)
      parse_resp(con.request(req))
    end
  end

  def self.prepare_req!(req)
    req.basic_auth(API_URL.user, '')
    req['Content-Type'] = 'applicaiton/json'
    req['User-Agent'] = 'chain-ruby/0'
  end

  def self.encode_body!(hash)
    begin
      JSON.dump(hash)
    rescue => e
      raise(ArgumentError, "Must be able to encode to JSON.")
    end
  end

  def self.parse_resp(resp)
      begin
        JSON.parse(resp.body)
      rescue => e
        raise ChainError
      end
  end

  def self.conn
    @conn ||= establish_conn
    @conn_mutex.synchronize do
      begin
        return yield(@conn)
      rescue => e
        @conn = nil
      end
    end
  end

  def self.establish_conn
    Net::HTTP.new(API_URL.host, API_URL.port).tap do |c|
      c.use_ssl = true
      c.verify_mode = OpenSSL::SSL::VERIFY_PEER
      c.ca_file = CHAIN_PEM
    end
  end

end

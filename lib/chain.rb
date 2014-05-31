require 'net/http'
require 'net/https'
require 'json'
require 'thread'

# A module that wraps the Chain HTTP API.
module Chain
  @conn_mutex = Mutex.new

  # Read's the URL from the environment.
  # Include API token in user portion of UIR.
  # E.g. https://API-TOKEN@api.chain.com
  API_URL = URI.parse(ENV['CHAIN_URL'] || raise("Must set CHAIN_URL."))
  # A collection of root certificates used by api.chain.com
  CHAIN_PEM = File.expand_path('../../chain.pem', __FILE__)
  # Prefixed in the path of HTTP requests.
  API_VERSION = 'v1'

  # Raised when an unexpected error occurs in either
  # the HTTP request or the parsing of the response body.
  ChainError = Class.new(StandardError)

  # Provide a bitcoin address.
  # Returns a hash.
  # Response details defined here: https://chain.com/#docs-address
  def self.get_address(addr)
    get("/#{API_VERSION}/bitcoin/addresses/#{addr}")
  end

  # Provide a bitcion address.
  # Returns an array of hashes.
  # Response details defined here: https://chain.com/#docs-unspents
  def self.get_unspent_outputs(addr)
    get("/#{API_VERSION}/bitcoin/addresses/#{addr}/unspents")
  end

  # Provide a hex encoded, signed transaction.
  # Returns a string representing the newly created transaction hash.
  def self.send_transactions(hex)
    r = put("/#{API_VERSION}/bitcoin/transactions", encode_body!({hex: hex}))
    r["transaction_hash"]
  end

  private

  def self.put(path, body)
    conn do |c|
      req = Net::HTTP::Put.new(API_URL.request_uri + path)
      prepare_req!(req)
      req.body = body
      parse_resp(c.request(req))
    end
  end

  def self.get(path)
    conn do |c|
      req = Net::HTTP::Get.new(API_URL.request_uri + path)
      prepare_req!(req)
      parse_resp(c.request(req))
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

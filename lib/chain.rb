require 'net/http'
require 'net/https'
require 'json'
require 'thread'
require 'uri'
require 'thread'

# A module that wraps the Chain HTTP API.
module Chain
  @conn_mutex = Mutex.new

  GUEST_KEY = 'GUEST-TOKEN'
  API_URL = URI('https://api.chain.com')

  # A collection of root certificates used by api.chain.com
  CHAIN_PEM = File.expand_path('../../chain.pem', __FILE__)
  # Prefixed in the path of HTTP requests.
  API_VERSION = 'v1'

  # Raised when an unexpected error occurs in either
  # the HTTP request or the parsing of the response body.
  ChainError = Class.new(StandardError)

  # Provide a Bitcoin address.
  # Returns basic details for a Bitcoin address (hash).
  def self.get_address(address)
    get("/#{API_VERSION}/bitcoin/addresses/#{address}")
  end

  # Provide a Bitcoin address.
  # Returns unspent transaction outputs for a Bitcoin address (array of hashes).
  def self.get_address_unspents(address)
    get("/#{API_VERSION}/bitcoin/addresses/#{address}/unspents")
  end
  
  # Provide a Bitcoin address.
  # Returns transactions for a Bitcoin address (array of hashes).
  def self.get_address_transactions(address, options={})
    get("/#{API_VERSION}/bitcoin/addresses/#{address}/transactions", options)
  end
  
  # Provide a Bitcoin address.
  # Returns transaction hashes for a Bitcoin address and retreives each transaction separately (array of hashes).
  # TODO - manage these threads outside a single connection 
  def self.get_address_transactions_slim(address, options={})
    tx_hashes = get("/#{API_VERSION}/bitcoin/addresses/#{address}/transactions/slim", options)
    
    transactions = []
    
    threads = tx_hashes.map do |i|
      Thread.new(i) do |i|
        transactions << get("/#{API_VERSION}/bitcoin/transactions/#{i}")
      end
    end
    threads.each {|t| t.join}
    
    transactions
  end
  
  # Provide a Bitcoin transaction.
  # Returns basic details for a Bitcoin transaction (hash).
  def self.get_transaction(hash)
    get("/#{API_VERSION}/bitcoin/transactions/#{hash}")
  end

  # Provide a hex encoded, signed transaction.
  # Returns the newly created Bitcoin transaction hash (string).
  def self.send_transaction(hex)
    r = put("/#{API_VERSION}/bitcoin/transactions", {hex: hex})
    r["transaction_hash"]
  end
  
  # Provide a Bitcoin block hash or height.
  # Returns basic details for a Bitcoin block (hash).
  def self.get_block(hash_or_height)
    get("/#{API_VERSION}/bitcoin/blocks/#{hash_or_height}")
  end
  
  # Get latest Bitcoin block.
  # Returns basic details for latest Bitcoin block (hash).
  def self.get_latest_block
    get("/#{API_VERSION}/bitcoin/blocks/latest")
  end
  
  # Set the key with the value found in your settings page on https://chain.com
  # If no key is set, Chain's guest token will be used. The guest token
  # should not be used for production services.
  def self.api_key=(key)
    @api_key = key
  end

  private

  def self.put(path, body)
    make_req!(Net::HTTP::Put, path, encode_body!(body))
  end

  def self.get(path, params={})    
    path = path + "?" + URI.encode_www_form(params) unless params.empty?
    make_req!(Net::HTTP::Get, path)
  end

  def self.make_req!(type, path, body=nil)
    conn do |c|
      req = type.new(path)
      req.basic_auth(api_key, '')
      req['Content-Type'] = 'application/json'
      req['User-Agent'] = 'chain-ruby/0'
      req.body = body
      parse_resp(c.request(req))
    end
  end

  def self.encode_body!(hash)
    begin
      JSON.dump(hash)
    rescue => e
      raise(ChainError, "JSON encoding error: #{e.message}")
    end
  end

  def self.parse_resp(resp)
    begin
      JSON.parse(resp.body)
    rescue => e
      raise(ChainError, "JSON decoding error: #{e.message}")
    end
  end

  def self.conn
    @conn ||= establish_conn
    @conn_mutex.synchronize do
      begin
        return yield(@conn)
      rescue => e
        @conn = nil
        raise(ChainError, "Connection error: #{e.message}")
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

  def self.api_key
    @api_key || key_from_env || GUEST_KEY
  end

  def self.key_from_env
    if url = ENV['CHAIN_URL']
      URI.parse(url).user
    end
  end

end

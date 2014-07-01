require 'digest/sha2'
require 'bigdecimal'
require 'bitcoin'

SATOSHI_PER_BITCOIN = BigDecimal.new("100000000")

class TransactionBuilder
  
  attr_accessor :from_address, :private_key, :to_address, :amount, :transaction_fee, :op_return, :keypair, :readable, :hex
  
  def initialize
    @unspent_outputs = []
    @inputs = []
    @outputs = []
  end

  def from_address= val
   @from_address = val
   @from_address_hex = Bitcoin.decode_base58(val)
   build_keypair
  end
  
  def private_key= val
   @private_key = val
   build_keypair
  end
  
  def to_address= val
   @to_address = val
   @to_address_hex = Bitcoin.decode_base58(val)
  end
  
  def amount= val
   @amount = BigDecimal.new(val)
   set_transaction_fee
  end
  
  def op_return= val
   @op_return = val.byteslice(0, 40) 
   @amount = BigDecimal.new("0.00")
   set_transaction_fee
  end
  
  def set_transaction_fee
    @transaction_fee = @amount >=  BigDecimal.new("0.01") ?  BigDecimal.new("0") :  BigDecimal.new("0.0001")
  end
  
  def build_and_sign
    self.build_inputs
    self.build_outputs
    self.build_tx
    self.sign_tx
  end
  
  def build_keypair
    if @from_address && @private_key
      w2 = Bitcoin.decode_base58(@private_key)
      w3 = w2[0..-9]
      secret = w3[2..-1]

      keypair = Bitcoin.open_key(secret)
      raise "Invalid keypair" unless keypair.check_key

      step_2 = (Digest::SHA2.new << [keypair.public_key_hex].pack("H*")).to_s   # (Digest::SHA2.new << [pubKey].pack("H*")).to_s -> bb905b336...
      step_3 = (Digest::RMD160.new << [step_2].pack("H*")).to_s                 # (Digest::RMD160.new << [step_2].pack("H*")).to_s -> 23376070c...
      step_4 = "00" + step_3                                                    # "00" + step_3
      step_5 = (Digest::SHA2.new << [step_4].pack("H*")).to_s                   # (Digest::SHA2.new << [step_4].pack("H*")).to_s
      step_6 = (Digest::SHA2.new << [step_5].pack("H*")).to_s                   # (Digest::SHA2.new << [step_5].pack("H*")).to_s
      step_7 = step_7 = step_6[0..7]                                            # step_7 = step_6[0..7] ->  b18a9aba
      step_8 = step_4 + step_7                                                  # step_4 + step_7 ->  00233760...b18a9aba
      step_9 = Bitcoin.encode_base58(step_8)                                    # Bitcoin.encode_base58(step_8)  -> 14DCzMe... which is the bitcoin address

      raise "Public key does not match private key" if @from_address != step_9

      @keypair = keypair
    end
  end
  
  def sufficient_funds?
    response = Chain.get_address(@from_address)
    balance = BigDecimal.new(response["balance"]) / SATOSHI_PER_BITCOIN
    
    if balance < @amount + @transaction_fee
      raise "Insufficient funds" if balance < @amount + @transaction_fee
    else
      return true
    end
  end
  
  def build_inputs
    @unspent_outputs = Chain.get_address_unspents(@from_address)

    input_total = BigDecimal.new("0")
    @unspent_outputs.each do |output|
      #p output["transaction_hash"].to_s
        @inputs <<  {
          previousTx: output["transaction_hash"],
          index: output["output_index"],
          scriptSig: nil # Sign it later
        }
        amount = BigDecimal.new(output["value"]) / SATOSHI_PER_BITCOIN
        #puts "Using #{amount.to_f} from output #{output["output_index"]} of transaction #{output["transaction_hash"][0..5]}..."
        input_total += amount
        break if input_total >= @amount + @transaction_fee
    end

    @change = input_total - @transaction_fee - @amount

    raise "Unable to process inputs for transaction" if input_total < @amount + @transaction_fee || @change < 0
  end
  
  def build_outputs
    unless @op_return.nil?
      message = @op_return
      message_hex = "%02X" % (message.each_byte.size)
      message_hex += message.each_byte.map { |b| "%02X" % b }.join
    end
    
    if @op_return.nil?
      @outputs = [
        { # Amount to transfer (leave out the leading zeros and 4 byte checksum)
            value: @amount,
            scriptPubKey: "OP_DUP OP_HASH160 " + (@to_address_hex[2..-9].size / 2).to_s(16) + " " + @to_address_hex[2..-9] + " OP_EQUALVERIFY OP_CHECKSIG "
            # OP_DUP is the default script: https://en.bitcoin.it/wiki/Script
          }
      ]
    else
      @outputs = [
        {
            value: BigDecimal.new("0.000"), # Unspendable 
            scriptPubKey: "OP_RETURN " + message_hex
          }
      ]
    end

    if @change > 0
      @outputs << {
        value: @change,
        scriptPubKey: "OP_DUP OP_HASH160 " + (@from_address_hex[2..-9].size / 2).to_s(16) + " " + @from_address_hex[2..-9] + " OP_EQUALVERIFY OP_CHECKSIG "
      }
      # Any property not specified in an output goes to the miners (transaction fee)
    end
  end
  
  def build_tx
    raise 'No inputs. Run build_inputs first.' if @inputs.empty?
    raise 'No outputs. Run build_outputs first.' if @outputs.empty?
    
    scriptSig = "OP_DUP OP_HASH160 " + (@from_address_hex[2..-9].size / 2).to_s(16) + " " + @from_address_hex[2..-9] + " OP_EQUALVERIFY OP_CHECKSIG "

    @inputs.collect!{|input|
      {
        previousTx: input[:previousTx],
        index: input[:index],
        # Add 1 byte for each script opcode:
        scriptLength: @from_address_hex[2..-9].length / 2 + 5,
        scriptSig: scriptSig,

        sequence_no: "ffffffff" # Ignored
      }
    }

    transaction = {
      version: 1,
      in_counter: @inputs.count,
      inputs: @inputs,
      out_counter: @outputs.count,
      outputs: @outputs,
      lock_time: 0,
      hash_code_type: "01000000" # Temporary value used during the signing process
    }

    # Serialize and create the input signatures. Then add these signatures back into the transaction and serialize it again.
    #puts "Readable version of the transaction (numbers in strings are hex, otherwise decimal)\n\n"
    #p transaction
    @readable = transaction
  end

  def sign_tx
    utx = serialize_transaction(@readable)

    #puts "\nHex unsigned transaction:"
    #puts @utx

    # Remove line breaks and spaces
    utx.gsub!("\n", "")
    utx.gsub!(" ", "")

    # Twice Sha256 and sign
    sha_first = (Digest::SHA2.new << [utx].pack("H*")).to_s
    sha_second = (Digest::SHA2.new << [sha_first].pack("H*")).to_s

    #puts "\nHash that we're going to sign: #{sha_second}"

    signature_binary = @keypair.dsa_sign_asn1([sha_second].pack("H*"))

    signature = signature_binary.unpack("H*").first

    hash_code_type = "01"
    signature_plus_hash_code_type_length = little_endian_hex_of_n_bytes((signature + hash_code_type).length / 2, 1)
    pub_key_length = little_endian_hex_of_n_bytes(@keypair.public_key_hex.length / 2, 1)

    scriptSig = signature_plus_hash_code_type_length + " " + signature + " "  + hash_code_type + " "  + pub_key_length + " " + @keypair.public_key_hex

    # Replace scriptSig and scriptLength for each of the inputs:
    @readable[:inputs].collect!{|input|
      {
        previousTx:   input[:previousTx],
        index:        input[:index],
        scriptLength: scriptSig.gsub(" ","").length / 2,
        scriptSig:    scriptSig,
        sequence_no:  input[:sequence_no]
      }
    }

    @readable[:hash_code_type] = ""

    hex = serialize_transaction(@readable)

    # Remove line breaks and spaces
    hex.gsub!("\n", "")
    hex.gsub!(" ", "")
    @hex = hex
  end
  
  def little_endian_hex_of_n_bytes(i, n)
    i.to_s(16).rjust(n * 2,"0").scan(/(..)/).reverse.join()
  end

  def parse_script(script)
    script.gsub("OP_DUP", "76").gsub("OP_HASH160", "a9").gsub("OP_EQUALVERIFY", "88").gsub("OP_CHECKSIG", "ac").gsub("OP_RETURN", "6a")
  end

  def serialize_transaction(transaction)
    tx = ""
    # Little endian 4 byte version number: 1 -> 01 00 00 00
    tx << little_endian_hex_of_n_bytes(transaction[:version],4) + "\n"
    # Could also use: transaction[:version].pack("V")

    # Number of inputs
    tx << little_endian_hex_of_n_bytes(transaction[:in_counter],1) + "\n"

    transaction[:inputs].each do |input|
      tx << little_endian_hex_of_n_bytes(input[:previousTx].hex, input[:previousTx].length / 2) + " "
      tx << little_endian_hex_of_n_bytes(input[:index],4) + "\n"
      tx << little_endian_hex_of_n_bytes(input[:scriptLength],1) + "\n"
      tx << parse_script(input[:scriptSig]) + " "
      tx << input[:sequence_no] + "\n"
    end

    # Number of outputs
    tx << little_endian_hex_of_n_bytes(transaction[:out_counter],1) + "\n"

    transaction[:outputs].each do |output|
      tx << little_endian_hex_of_n_bytes((output[:value] * SATOSHI_PER_BITCOIN).to_i,8) + "\n"
      unparsed_script = output[:scriptPubKey]
      #puts "UNPARSED: ------------------------------"
      #puts unparsed_script
      tx << little_endian_hex_of_n_bytes(parse_script(unparsed_script).gsub(" ", "").length / 2, 1) + "\n"
      #puts little_endian_hex_of_n_bytes(parse_script(unparsed_script).gsub(" ", "").length / 2, 1) + "\n"
      tx << parse_script(unparsed_script) + "\n"
      #puts parse_script(unparsed_script) + "\n"
    end

    tx << little_endian_hex_of_n_bytes(transaction[:lock_time],4) + "\n"
    tx << transaction[:hash_code_type] # This is empty after signing
    tx
  end
end
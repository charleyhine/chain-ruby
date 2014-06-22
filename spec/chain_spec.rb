require 'spec_helper'

describe Chain do
  
  before :all do
      @address = '12mXqGPQyPsABMqCAGzy5LMSfpitzMqVdM'
      @transaction = '60a618bdcb85d218d2b9caeaa43e4b3519945949d3b2b7ee6085bb2ebb62f9ce'
      @block_hash = '00000000000000000f4bb6c214d0d797adf8c66a8d006170915332968d1de0e8'
      @block_height = '307263'
  end
  
  it { should respond_to(:send_transaction) }
  
  describe "#get_address" do
      it "takes a base58 public key and returns a Ruby hash" do
        expect(Chain.get_address(@address)).to be_an_instance_of Hash
      end
      
      it "takes a base58 public key (address) and returns the address in response" do
        expect(Chain.get_address(@address)['hash']).to eq(@address)
      end
  end
  
  describe "#get_address_unspents" do
      it "takes a base58 public key and returns a Ruby array" do
        expect(Chain.get_address_unspents(@address)).to be_an_instance_of Array
      end
  end
  
  describe "#get_address_transactions" do
      it "takes a base58 public key and returns a Ruby array" do
        expect(Chain.get_address_transactions(@address)).to be_an_instance_of Array
      end
  end
  
  describe "#get_transaction" do
      it "takes a transaction hash and returns a Ruby hash" do
        expect(Chain.get_transaction(@transaction)).to be_an_instance_of Hash
      end
  end
  
  describe "#get_block" do
      it "takes a block hash and returns a Ruby hash" do
        expect(Chain.get_block(@block_hash)).to be_an_instance_of Hash
      end
      
      it "takes a block hash and returns corresponding block data" do
        expect(Chain.get_block(@block_hash)['hash']).to eq(@block_hash)
      end
      
      it "takes a block height and returns a Ruby hash" do
        expect(Chain.get_block(@block_height)).to be_an_instance_of Hash
      end
  end
  
  describe "#get_latest_block" do
      it "returns a Ruby hash" do
        expect(Chain.get_latest_block).to be_an_instance_of Hash
      end
  end

end
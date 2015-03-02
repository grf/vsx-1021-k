$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

require 'trie'
require 'helpers'

RSpec.describe Trie do
  include TrieHelpers

  describe "#new" do
    it "test_data_1 creates a new trie with approriate keys and values" do
      tr = test_data_1
      expect(tr.keys.length).to eq(7)
      expect(tr.values.length).to eq(7)
    end
  end


  # describe "" do
  #   it "" do
  #   end
  # end


end

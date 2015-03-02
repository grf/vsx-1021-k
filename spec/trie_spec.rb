$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

require 'trie'
require 'helpers'

RSpec.describe Trie do
  include TrieHelpers

  describe "#new" do
    it "test_data_1 creates a new trie with approriate keys and values" do
      tr = test_data_1

      expect(tr.keys.length).to   eq(7)
      expect(tr.values.length).to eq(7)

      expect(tr['silos.darchive.fcla.edu:/daitssfs/001']).to eq(:a)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/002']).to eq(:b)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/003']).to eq(:c)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/004']).to eq(:d)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/010']).to eq(:e)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/015']).to eq(:f)
      expect(tr['silos.darchive.fcla.edu:/daitssfs/027']).to eq(:g)
    end
  end

  describe "#new" do
    it "test_data_1 creates a new trie with correctly sorted values" do
      tr = test_data_1
      keys = tr.keys

      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/001')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/002')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/003')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/004')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/010')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/015')
      expect(keys.shift).to eq('silos.darchive.fcla.edu:/daitssfs/027')
    end
  end

  # to do: expect updatres; expect removal; expect sorted; expect longest common substring....


  # describe "" do
  #   it "" do
  #   end
  # end
end

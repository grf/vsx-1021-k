module TrieHelpers
  def test_data_1

    trie = Trie.new

    trie['silos.darchive.fcla.edu:/daitssfs/001'] = :a
    trie['silos.darchive.fcla.edu:/daitssfs/002'] = :b
    trie['silos.darchive.fcla.edu:/daitssfs/003'] = :c
    trie['silos.darchive.fcla.edu:/daitssfs/004'] = :d
    trie['silos.darchive.fcla.edu:/daitssfs/010'] = :e
    trie['silos.darchive.fcla.edu:/daitssfs/015'] = :f
    trie['silos.darchive.fcla.edu:/daitssfs/027'] = :g

    return trie
  end



  #  trie['silos.darchive.fcla.edu:/daitssfs/002']     => :c
  #
  #
  #  trie.keys   =>  [ "silos.darchive.fcla.edu:/daitssfs/001", "silos.darchive.fcla.edu:/daitssfs/002", .. ]
  #  trie.values =>  [ :a, :c, :d, :e, :f, :g ]
  #
  #  trie.prefix => 'silos.darchive.fcla.edu:/daitssfs/0'
  #
  #  trie.twigs  => [ '01', '02', '04', '10', '15', '27' ]


end

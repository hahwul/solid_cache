# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      assert_equal 0, Entry.estimated_size
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      assert_equal 415, Entry.estimated_size(samples: 12)
      assert_equal 415, Entry.estimated_size(samples: 10)
      assert_equal 456, Entry.estimated_size(samples: 6)
      assert_equal 457, Entry.estimated_size(samples: 5)
    end

    test "test larger sample estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)

      assert_equal 369257, Entry.estimated_size(samples: 1000)
      assert_equal 369550, Entry.estimated_size(samples: 500)
      with_fixed_srand(1) { assert_equal 383576, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal 357109, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal 326614, Entry.estimated_size(samples: 10) }
    end

    test "test with gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 3
      Entry.where("id % 3 = #{first_mod}").delete_all

      assert_equal 249940, Entry.estimated_size(samples: 1000)
      assert_equal 250037, Entry.estimated_size(samples: 500)
      with_fixed_srand(1) { assert_equal 249354, Entry.estimated_size(samples: 334) }
      with_fixed_srand(1) { assert_equal 267523, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal 257970, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal 203365, Entry.estimated_size(samples: 10) }
    end

    test "test with more gaps in records estimates" do
      values_lengths = with_fixed_srand(1) { 1000.times.map { (rand**2 * 1000).to_i } }
      write_entries(value_lengths: values_lengths)
      first_mod = Entry.first.id % 4
      Entry.where("id % 4 != #{first_mod}").delete_all

      assert_equal 92304, Entry.estimated_size(samples: 1000)
      assert_equal 92592, Entry.estimated_size(samples: 500)
      with_fixed_srand(1) { assert_equal 92519, Entry.estimated_size(samples: 250) }
      with_fixed_srand(1) { assert_equal 95475, Entry.estimated_size(samples: 100) }
      with_fixed_srand(1) { assert_equal 101601, Entry.estimated_size(samples: 50) }
      with_fixed_srand(1) { assert_equal 13362, Entry.estimated_size(samples: 10) }
    end

    test "overestimate when all samples sizes are the same" do
      # This is a pathological case where the bytes sizes are all the same, and
      # the outliers are not outliers at all. Ensure we over rather than under
      # estimate in this case.
      write_entries(value_lengths: [1] * 1000)

      assert_equal 37000, Entry.estimated_size(samples: 1000)
      assert_equal 73963, Entry.estimated_size(samples: 999)
      assert_equal 55500, Entry.estimated_size(samples: 500)
      with_fixed_srand(1) { assert_equal 67648, Entry.estimated_size(samples: 6) }
      with_fixed_srand(1) { assert_equal 81178, Entry.estimated_size(samples: 5) }
    end

    private
      def write_entries(value_lengths:)
        Entry.write_multi(value_lengths.map.with_index { |value_length, index| { key: "key#{index.to_s.rjust(5, "0")}", value: "a" * value_length } })
      end

      def with_fixed_srand(seed)
        old_srand = srand(seed)
        yield
      ensure
        srand(old_srand)
      end
  end
end

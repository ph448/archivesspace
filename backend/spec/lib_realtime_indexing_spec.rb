require 'spec_helper'
require_relative '../app/lib/realtime_indexing'

describe 'Realtime indexing' do

  before(:each) do
    RealtimeIndexing.reset!
  end


  context "simple updates" do

    let!(:acc) { create(:json_accession) }
    sleep(0.05)
    let!(:acc2) { create(:json_accession) }


    it "records updates" do
      updates = RealtimeIndexing.updates_since(0)

      expect(updates.count).to eq(2)

      expect(updates[0][:uri]).to eq(acc.uri)
      expect(updates[1][:uri]).to eq(acc2.uri)
    end


    it "gives out incrementing sequence numbers" do
      updates = RealtimeIndexing.updates_since(0)
      expect(updates[0][:sequence]).to eq(updates[1][:sequence] - 1)
    end


    it "skips over updates that the caller has seen already" do
      updates = RealtimeIndexing.updates_since(0)

      expect(RealtimeIndexing.updates_since(updates[1][:sequence]).count).to eq(0)
    end


    it "records millisecond timestamps for entries in the list" do
      updates = RealtimeIndexing.updates_since(0)
      expect(updates[0][:timestamp]).to be < updates[1][:timestamp]
    end

  end


  context "concurrency" do

    class FakeRecord
      def self.uri_for(id)
        "/something/#{id}"
      end

      def to_hash
        {}
      end
    end


    it "is thread safe" do
      thread_count = 5
      count = 100
      threads = []

      dummy_record = FakeRecord.new

      thread_count.times do
        threads << Thread.new do
          count.times do
            RealtimeIndexing.record_update(dummy_record, 1)
          end
        end
      end


      threads.each {|thread| thread.join}

      expect(RealtimeIndexing.updates_since(0).count).to eq(thread_count * count)
    end


    it "blocks a thread until an element becomes available" do

      waiter = Thread.new do
        RealtimeIndexing.blocking_updates_since(0)
      end

      sleep 0.05
      acc = create(:json_accession)

      result = waiter.join

      expect(result.value[0]).not_to be_nil
      expect(result.value[0][:uri]).to eq(acc.uri)
    end

  end

end

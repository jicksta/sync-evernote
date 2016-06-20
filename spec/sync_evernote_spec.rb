require 'spec_helper'

describe SyncEvernote do

  describe "#modified_notes" do
    it "returns the first note when called with 0 or 1"
    it "does not have any modified_notes when invoking with max_remote_usn"
  end
  
end

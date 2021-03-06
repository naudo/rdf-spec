require 'rdf'
require 'rdf/spec'
require 'rdf/ntriples'

shared_examples_for :RDF_Mutable do
  include RDF::Spec::Matchers

  before :each do
    raise '+@mutable+ must be defined in a before(:each) block' unless instance_variable_get('@mutable')

    @filename = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'etc', 'doap.nt'))

    @subject = RDF::URI('http://rubygems.org/gems/rdf')
    @context = RDF::URI('http://example.org/context')

    # Assume contexts are supported unless declared otherwise:
    @supports_context = @mutable.respond_to?(:supports?) ? @mutable.supports?(:context) : true
  end

  it "should be empty initially" do
    @mutable.empty?.should be_true
    @mutable.count.should be_zero
  end

  it "should be readable" do
    @mutable.readable?.should be_true
  end

  it "should be writable" do
    @mutable.writable?.should be_true
  end

  it "should be mutable" do
    @mutable.immutable?.should be_false
    @mutable.mutable?.should be_true
  end

  it "should support #load" do
    @mutable.respond_to?(:load).should be_true
  end

  context "#load" do
    it "should require an argument" do
      lambda { @mutable.load }.should raise_error(ArgumentError)
    end

    it "should accept a string filename argument" do
      lambda { @mutable.load(@filename) }.should_not raise_error(ArgumentError)
    end

    it "should accept an optional hash argument" do
      lambda { @mutable.load(@filename,{}) }.should_not raise_error(ArgumentError)
    end

    it "should load statements" do
      @mutable.load @filename
      @mutable.size.should ==  File.readlines(@filename).size
      @mutable.should have_subject(@subject)
    end

    it "should load statements with a context override" do
      @mutable.load @filename, :context => @context
      @mutable.should have_context(@context)
      @mutable.query(:context => @context).size.should == @mutable.size
    end
  end

  context "when inserting statements" do
    before :each do
      @statements = RDF::NTriples::Reader.new(File.open(@filename)).to_a
    end

    it "should support #insert" do
      @mutable.should respond_to(:insert)
    end

    it "should not raise errors" do
      lambda { @mutable.insert(@statements.first) }.should_not raise_error
    end

    it "should support inserting one statement at a time" do
      @mutable.insert(@statements.first)
      @mutable.should have_statement(@statements.first)
    end

    it "should support inserting multiple statements at a time" do
      @mutable.insert(*@statements)
    end

    it "should insert statements successfully" do
      @mutable.insert(*@statements)
      @mutable.count.should == @statements.size
    end

    it "should not insert a statement twice" do
      @mutable.insert(@statements.first)
      @mutable.insert(@statements.first)
      @mutable.count.should == 1
    end

    it "should treat statements with a different context as distinct" do
      s1 = @statements.first.dup
      s1.context = nil
      s2 = @statements.first.dup
      s2.context = RDF::URI.new("urn:context:1")
      s3 = @statements.first.dup
      s3.context = RDF::URI.new("urn:context:2")
      @mutable.insert(s1)
      @mutable.insert(s2)
      @mutable.insert(s3)
      # If contexts are not suported, all three are redundant
      @mutable.count.should == (@supports_context ? 3 : 1)
    end

  end

  context "when deleting statements" do
    before :each do
      @statements = RDF::NTriples::Reader.new(File.open(@filename)).to_a
      @mutable.insert(*@statements)
    end

    it "should support #delete" do
      @mutable.should respond_to(:delete)
    end

    it "should not raise errors" do
      lambda { @mutable.delete(@statements.first) }.should_not raise_error
    end

    it "should support deleting one statement at a time" do
      @mutable.delete(@statements.first)
      @mutable.should_not have_statement(@statements.first)
    end

    it "should support deleting multiple statements at a time" do
      @mutable.delete(*@statements)
      @statements.find { |s| @mutable.has_statement?(s) }.should be_false
    end

    it "should support wildcard deletions" do
      # nothing deleted
      require 'digest/sha1'
      count = @mutable.count
      @mutable.delete([nil, nil, random = Digest::SHA1.hexdigest(File.read(__FILE__))])
      @mutable.should_not be_empty
      @mutable.count.should == count

      # everything deleted
      @mutable.delete([nil, nil, nil])
      @mutable.should be_empty
    end

    it "should only delete statements when the context matches" do
      # Setup three statements identical except for context
      count = @mutable.count + (@supports_context ? 3 : 1)
      s1 = RDF::Statement.new(@subject, RDF::URI.new("urn:predicate:1"), RDF::URI.new("urn:object:1"))
      s2 = s1.dup
      s2.context = RDF::URI.new("urn:context:1")
      s3 = s1.dup
      s3.context = RDF::URI.new("urn:context:2")
      @mutable.insert(s1)
      @mutable.insert(s2)
      @mutable.insert(s3)
      @mutable.count.should == count

      # Delete one by one
      @mutable.delete(s1)
      @mutable.count.should == count - (@supports_context ? 1 : 1)
      @mutable.delete(s2)
      @mutable.count.should == count - (@supports_context ? 2 : 1)
      @mutable.delete(s3)
      @mutable.count.should == count - (@supports_context ? 3 : 1)
    end
  end

  context "when clearing all statements" do
    it "should support #clear" do
      @mutable.should respond_to(:clear)
    end
  end
end

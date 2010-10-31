require 'rdf/spec'
require 'rspec'

shared_examples_for :RDF_Enumerable do
  include RDF::Spec::Matchers

  before :each do
    raise '+@enumerable+ must be defined in a before(:each) block' unless instance_variable_get('@enumerable')

    @filename   = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'etc', 'doap.nt'))
    @statements ||= RDF::NTriples::Reader.new(File.open(@filename)).to_a

    if @enumerable.empty?
      if @enumerable.respond_to?(:<<)
        @statements.each { |statement| @enumerable << statement }
      else
        raise "@enumerable must respond to #<< or be pre-populated with the statements in #{@filename} in a before(:each) block"
      end
    end

    # Assume contexts are supported unless declared otherwise:
    @supports_context = @enumerable.respond_to?(:supports?) ? @enumerable.supports?(:context) : true
  end

  context "when counting statements" do
    it "should respond to #empty?" do
      @enumerable.should respond_to(:empty?)
    end

    it "should respond to #count and #size" do
      @enumerable.should respond_to(*%w(count size length))
    end

    it "should implement #empty?" do
      ([].extend(RDF::Enumerable)).empty?.should be_true
      @enumerable.empty?.should be_false
    end

    it "should implement #count and #size" do
      %w(count size length).each do |method|
        @enumerable.send(method).should == @statements.size
      end
    end
  end

  context "when enumerating statements" do
    it "should respond to #statements" do
      @enumerable.should respond_to(:statements)
    end

    it "should respond to #has_statement?" do
      @enumerable.should respond_to(:has_statement?)
    end

    it "should respond to #each_statement" do
      @enumerable.should respond_to(:each_statement)
    end

    it "should respond to #enum_statement" do
      @enumerable.should respond_to(:enum_statement)
    end

    it "should implement #statements" do
      @enumerable.statements.should be_an_enumerator
      @enumerable.statements.to_a.size.should == @statements.size
      @enumerable.statements.each { |statement| statement.should be_a_statement }
    end

    it "should implement #has_statement?" do
      @statements.each do |statement|
        @enumerable.has_statement?(statement).should be_true
      end

      context = RDF::URI.new("urn:context:1")
      @statements.each do |statement|
        s = statement.dup
        s.context = context
        @enumerable.has_statement?(s).should be_false
      end

      unknown_statement = RDF::Statement.new(RDF::Node.new, RDF::URI.new("http://example.org/unknown"), RDF::Node.new)
      @enumerable.has_statement?(unknown_statement).should be_false
    end

    it "should implement #each_statement" do
      @enumerable.each_statement.should be_an_enumerator
      @enumerable.each_statement { |statement| statement.should be_a_statement }
    end

    it "should implement #enum_statement" do
      @enumerable.enum_statement.should be_an_enumerator
      @enumerable.enum_statement.should be_countable
      @enumerable.enum_statement.should be_enumerable
      @enumerable.enum_statement.should be_queryable
      @enumerable.enum_statement.to_a.should == @enumerable.each_statement.to_a
    end
  end

  context "when enumerating triples" do
    it "should respond to #triples" do
      @enumerable.should respond_to(:triples)
    end

    it "should respond to #has_triple?" do
      @enumerable.should respond_to(:has_triple?)
    end

    it "should respond to #each_triple" do
      @enumerable.should respond_to(:each_triple)
    end

    it "should respond to #enum_triple" do
      @enumerable.should respond_to(:enum_triple)
    end

    it "should implement #triples" do
      @enumerable.triples.should be_an_enumerator
      @enumerable.triples.to_a.size.should == @statements.size
      @enumerable.triples.each { |triple| triple.should be_a_triple }
    end

    it "should implement #has_triple?" do
      @statements.each do |statement|
        @enumerable.has_triple?(statement.to_triple).should be_true
      end
    end

    it "should implement #each_triple" do
      @enumerable.each_triple.should be_an_enumerator
      @enumerable.each_triple { |*triple| triple.should be_a_triple }
    end

    it "should implement #enum_triple" do
      @enumerable.enum_triple.should be_an_enumerator
      @enumerable.enum_triple.should be_countable
      @enumerable.enum_triple.to_a.should == @enumerable.each_triple.to_a
    end
  end

  context "when enumerating quads" do
    it "should respond to #quads" do
      @enumerable.should respond_to(:quads)
    end

    it "should respond to #has_quad?" do
      @enumerable.should respond_to(:has_quad?)
    end

    it "should respond to #each_quad" do
      @enumerable.should respond_to(:each_quad)
    end

    it "should respond to #enum_quad" do
      @enumerable.should respond_to(:enum_quad)
    end

    it "should implement #quads" do
      @enumerable.quads.should be_an_enumerator
      @enumerable.quads.to_a.size.should == @statements.size
      @enumerable.quads.each { |quad| quad.should be_a_quad }
    end

    it "should implement #has_quad?" do
      @statements.each do |statement|
        @enumerable.has_quad?(statement.to_quad).should be_true
      end
    end

    it "should implement #each_quad" do
      @enumerable.each_quad.should be_an_enumerator
      @enumerable.each_quad { |*quad| quad.should be_a_quad }
    end

    it "should implement #enum_quad" do
      @enumerable.enum_quad.should be_an_enumerator
      @enumerable.enum_quad.should be_countable
      @enumerable.enum_quad.to_a.should == @enumerable.each_quad.to_a
    end
  end

  context "when enumerating subjects" do
    it "should respond to #subjects" do
      @enumerable.should respond_to(:subjects)
    end

    it "should respond to #has_subject?" do
      @enumerable.should respond_to(:has_subject?)
    end

    it "should respond to #each_subject" do
      @enumerable.should respond_to(:each_subject)
    end

    it "should respond to #enum_subject" do
      @enumerable.should respond_to(:enum_subject)
    end

    it "should implement #subjects" do
      @enumerable.subjects.should be_an_enumerator
      @enumerable.subjects.each { |value| value.should be_a_resource }
      # TODO: subjects(:unique => false)
    end

    it "should implement #has_subject?" do
      checked = []
      @statements.each do |statement|
        @enumerable.has_subject?(statement.subject).should be_true unless checked.include?(statement.subject)
        checked << statement.subject
      end
      uri = RDF::URI.new('http://example.org/does/not/have/this/uri')
      @enumerable.has_predicate?(uri).should be_false
    end

    it "should implement #each_subject" do
      @enumerable.each_subject.should be_an_enumerator
      subjects = @statements.map { |s| s.subject }.uniq
      @enumerable.each_subject.to_a.size.should == subjects.size
      @enumerable.each_subject do |value|
        value.should be_a_value
        subjects.should include(value)
      end
    end

    it "should implement #enum_subject" do
      @enumerable.enum_subject.should be_an_enumerator
      @enumerable.enum_subject.should be_countable
      @enumerable.enum_subject.to_a.should == @enumerable.each_subject.to_a
    end
  end

  context "when enumerating predicates" do
    it "should respond to #predicates" do
      @enumerable.should respond_to(:predicates)
    end

    it "should respond to #has_predicate?" do
      @enumerable.should respond_to(:has_predicate?)
    end

    it "should respond to #each_predicate" do
      @enumerable.should respond_to(:each_predicate)
    end

    it "should respond to #enum_predicate" do
      @enumerable.should respond_to(:enum_predicate)
    end

    it "should implement #predicates" do
      @enumerable.predicates.should be_an_enumerator
      @enumerable.predicates.each { |value| value.should be_a_uri }
      # TODO: predicates(:unique => false)
    end

    it "should implement #has_predicate?" do
      checked = []
      @statements.each do |statement|
        @enumerable.has_predicate?(statement.predicate).should be_true unless checked.include?(statement.object)
        checked << statement.predicate
      end
      uri = RDF::URI.new('http://example.org/does/not/have/this/uri')
      @enumerable.has_predicate?(uri).should be_false
    end

    it "should implement #each_predicate" do
      predicates = @statements.map { |s| s.predicate }.uniq
      @enumerable.each_predicate.should be_an_enumerator
      @enumerable.each_predicate.to_a.size.should == predicates.size
      @enumerable.each_predicate do |value|
        value.should be_a_uri
        predicates.should include(value)
      end
    end

    it "should implement #enum_predicate" do
      @enumerable.enum_predicate.should be_an_enumerator
      @enumerable.enum_predicate.should be_countable
      @enumerable.enum_predicate.to_a.should == @enumerable.each_predicate.to_a
    end
  end

  context "when enumerating objects" do
    it "should respond to #objects" do
      @enumerable.should respond_to(:objects)
    end

    it "should respond to #has_object?" do
      @enumerable.should respond_to(:has_object?)
    end

    it "should respond to #each_object" do
      @enumerable.should respond_to(:each_object)
    end

    it "should respond to #enum_object" do
      @enumerable.should respond_to(:enum_object)
    end

    it "should implement #objects" do
      @enumerable.objects.should be_an_enumerator
      @enumerable.objects.each { |value| value.should be_a_value }
      # TODO: objects(:unique => false)
    end

    it "should implement #has_object?" do
      checked = []
      @statements.each do |statement|
        @enumerable.has_object?(statement.object).should be_true unless checked.include?(statement.object)
        checked << statement.object
      end
      uri = RDF::URI.new('http://example.org/does/not/have/this/uri')
      @enumerable.has_object?(uri).should be_false
    end

    it "should implement #each_object" do
      objects = @statements.map { |s| s.object }.uniq
      @enumerable.each_object.should be_an_enumerator
      @enumerable.each_object.to_a.size.should == objects.size
      @enumerable.each_object do |value|
        value.should be_a_value
        objects.should include(value)
      end
    end

    it "should implement #enum_object" do
      @enumerable.enum_object.should be_an_enumerator
      @enumerable.enum_object.should be_countable
      @enumerable.enum_object.to_a.should == @enumerable.each_object.to_a
    end
  end

  context "when enumerating contexts" do
    it "should respond to #contexts" do
      @enumerable.should respond_to(:contexts)
    end

    it "should respond to #has_context?" do
      @enumerable.should respond_to(:has_context?)
    end

    it "should respond to #each_context" do
      @enumerable.should respond_to(:each_context)
    end

    it "should respond to #enum_context" do
      @enumerable.should respond_to(:enum_context)
    end

    it "should implement #contexts" do
      @enumerable.contexts.should be_an_enumerator
      @enumerable.contexts.each { |value| value.should be_a_resource }
      # TODO: contexts(:unique => false)
    end

    it "should implement #has_context?" do
      @statements.each do |statement|
        if statement.has_context?
          @enumerable.has_context?(statement.context).should be_true
        end
      end
      uri = RDF::URI.new('http://example.org/does/not/have/this/uri')
      @enumerable.has_context?(uri).should be_false
    end

    it "should implement #each_context" do
      contexts = @statements.map { |s| s.context }.uniq
      contexts.delete nil
      @enumerable.each_context.should be_an_enumerator
      @enumerable.each_context.to_a.size.should == contexts.size
      @enumerable.each_context do |value|
        value.should be_a_resource
        contexts.should include(value)
      end
    end

    it "should implement #enum_context" do
      @enumerable.enum_context.should be_an_enumerator
      @enumerable.enum_context.should be_countable
      @enumerable.enum_context.to_a.should == @enumerable.each_context.to_a
    end
  end

  context "when enumerating graphs" do
    it "should respond to #each_graph" do
      @enumerable.should respond_to(:enum_graph)
    end

    it "should respond to #enum_graph" do
      @enumerable.should respond_to(:enum_graph)
    end

    it "should implement #each_graph" do
      @enumerable.each_graph.should be_an_enumerator
      @enumerable.each_graph { |graph| graph.should be_a_graph }
      # TODO: relying on #contexts, check that the returned values are correct.
    end

    it "should implement #enum_graph" do
      @enumerable.enum_graph.should be_an_enumerator
      @enumerable.enum_graph.should be_countable
      @enumerable.enum_graph.to_a.should == @enumerable.each_graph.to_a
    end
  end

  context "when converting" do
    it "should respond to #to_hash" do
      @enumerable.should respond_to(:to_hash)
    end

    it "should implement #to_hash" do
      @enumerable.to_hash.should be_instance_of(Hash)
      @enumerable.to_hash.keys.size.should == @enumerable.subjects.to_a.size
    end
  end
end

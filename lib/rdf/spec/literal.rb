# coding: utf-8
require 'rdf'
require 'rdf/spec'

shared_examples_for :RDF_Literal do
  XSD = RDF::XSD

  before :each do
    raise '+@new+ must be defined in a before(:each) block' unless instance_variable_get('@new')
  end

  def self.literal(selector)
    case selector
    when :empty       then ['']
    when :plain       then ['Hello']
    when :empty_lang  then ['', {:language => :en}]
    when :plain_lang  then ['Hello', {:language => :en}]
    when :false       then [false]
    when :true        then [true]
    when :int         then [123]
    when :long        then [9223372036854775807]
    when :double      then [3.1415]
    when :date        then [Date.new(2010)]
    when :datetime    then [DateTime.new(2011)]
    when :time        then [Time.parse('01:02:03Z')]
    when :date        then [Date.new(2010)]
    when :xml_no_ns   then ["foo <sup>bar</sup> baz!", {:datatype => RDF.XMLLiteral}]
    when :xml_ns      then ["foo <sup>bar</sup> baz!", {:datatype => RDF.XMLLiteral,
                            :namespaces => {"dc" => RDF::DC.to_s}}]
    when :xml_ns2     then ["foo <sup xmlns:dc=\"http://purl.org/dc/terms/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">bar</sup> baz!",
                           {:datatype => RDF.XMLLiteral,
                           :namespaces => {"" => RDF::DC.to_s}}]
    when :xml_ns_lang then ["foo <sup>bar</sup> baz!", {:datatype => RDF.XMLLiteral,
                           :namespaces => {"dc" => RDF::DC.to_s}, :language => :fr}]
    when :xml_lang_em then ["foo <sup>bar</sup><sub xml:lang=\"en\">baz</sub>",
                           {:datatype => RDF.XMLLiteral,
                           :namespaces => {"dc" => RDF::DC.to_s},
                           :language => :fr}]
    when :xml_def_ns  then ["foo <sup>bar</sup> baz!", {:datatype => RDF.XMLLiteral,
                           :namespaces => {"" => RDF::DC.to_s}}]
    else
      raise("unexpected literal: :#{selector}")
    end
  end
  
  def self.literals(*selector)
    selector.inject([]) do |ary, sel|
      ary += case sel
      when :all_plain_no_lang then [:empty, :plain].map {|sel| literal(sel)}
      when :all_plain_lang    then [:empty_lang, :plain_lang].map {|sel| literal(sel)}
      when :all_native        then [:false, :true, :int, :long, :double, :time, :date, :datetime].map {|sel| literal(sel)}
      when :all_xml           then [:xml_no_ns, :xml_ns, :xml_ns2, :xml_ns_lang, :xml_lang_em, :xml_def_ns].map {|sel| literal(sel)}
      when :all_plain         then literals(:all_plain_no_lang, :all_plain_lang)
      else                         literals(:all_plain, :all_native, :all_xml)
      end
    end
  end
  
  describe "new" do
    it "instantiates empty string" do
      lambda { @new.call('') }.should_not raise_error
    end

    it "instantiates empty string with language" do
      lambda { @new.call('', :language => :en) }.should_not raise_error
    end
    
    it "instantiates from native datatype" do
      lambda { @new.call(123) }.should_not raise_error
    end

    describe "c18n" do
      it "normalizes language to lower-case" do
        @new.call('Upper', :language => :EN, :canonicalize => true).language.should == :en
      end
    
      it "supports sub-taged language specification" do
        @new.call('Hi', :language => :"en-us", :canonicalize => true).language.should == :"en-us"
      end

      {
        "true"  => "true",
        "false" => "false",
        "tRuE"  => "true",
        "FaLsE" => "false",
        "1"     => "true",
        "0"     => "false",
      }.each_pair do |value, str|
        it "does not normalize boolean '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.boolean, :canonicalize => false).to_s.should == value
        end

        it "normalizes boolean '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.boolean, :canonicalize => true).to_s.should == str
        end
      end

      {
        "01" => "1",
        "1"  => "1",
        "-1" => "-1",
        "+1" => "1",
      }.each_pair do |value, str|
        it "does not normalize integer '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.integer, :canonicalize => false).to_s.should == value
        end

        it "normalizes integer '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.integer, :canonicalize => true).to_s.should == str
        end
      end

      {
        "1"                              => "1.0",
        "-1"                             => "-1.0",
        "1."                             => "1.0",
        "1.0"                            => "1.0",
        "1.00"                           => "1.0",
        "+001.00"                        => "1.0",
        "123.456"                        => "123.456",
        "2.345"                          => "2.345",
        "1.000000000"                    => "1.0",
        "2.3"                            => "2.3",
        "2.234000005"                    => "2.234000005",
        "2.2340000000000005"             => "2.2340000000000005",
        "2.23400000000000005"            => "2.234",
        "2.23400000000000000000005"      => "2.234",
        "1.2345678901234567890123457890" => "1.2345678901234567",
      }.each_pair do |value, str|
        it "does not normalize decimal '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.decimal, :canonicalize => false).to_s.should == value
        end

        it "normalizes decimal '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.decimal, :canonicalize => true).to_s.should == str
        end
      end

      {
        "1"         => "1.0E0",
        "-1"        => "-1.0E0",
        "+01.000"   => "1.0E0",
        #"1."        => "1.0E0",
        "1.0"       => "1.0E0",
        "123.456"   => "1.23456E2",
        "1.0e+1"    => "1.0E1",
        "1.0e-10"   => "1.0E-10",
        "123.456e4" => "1.23456E6",
      }.each_pair do |value, str|
        it "does not normalize double '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.double, :canonicalize => false).to_s.should == value
        end

        it "normalizes double '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.double, :canonicalize => true).to_s.should == str
        end
      end
  
      # DateTime
      {
        "2010-01-01T00:00:00Z"      => "2010-01-01T00:00:00Z",
        "2010-01-01T00:00:00.0000Z" => "2010-01-01T00:00:00Z",
        "2010-01-01T00:00:00"       => "2010-01-01T00:00:00Z",
        "2010-01-01T00:00:00+00:00" => "2010-01-01T00:00:00Z",
        "2010-01-01T01:00:00+01:00" => "2010-01-01T00:00:00Z",
        "2009-12-31T23:00:00-01:00" => "2010-01-01T00:00:00Z",
        "-2010-01-01T00:00:00Z"     => "-2010-01-01T00:00:00Z",
      }.each_pair do |value, str|
        it "does not normalize dateTime '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.dateTime, :canonicalize => false).to_s.should == value
        end

        it "normalizes dateTime '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.dateTime, :canonicalize => true).to_s.should == str
        end
      end
  
      # Date
      {
        "2010-01-01Z"      => "2010-01-01Z",
        "2010-01-01"       => "2010-01-01Z",
        "2010-01-01+00:00" => "2010-01-01Z",
        "2010-01-01+01:00" => "2010-01-01Z",
        "2009-12-31-01:00" => "2009-12-31Z",
        "-2010-01-01Z"     => "-2010-01-01Z",
      }.each_pair do |value, str|
        it "does not normalize date '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.date, :canonicalize => false).to_s.should == value
        end

        it "normalizes date '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.date, :canonicalize => true).to_s.should == str
        end
      end
  
  
      # Time
      {
        "00:00:00Z"      => "00:00:00Z",
        "00:00:00.0000Z" => "00:00:00Z",
        "00:00:00+00:00" => "00:00:00Z",
        "01:00:00+01:00" => "00:00:00Z",
        "23:00:00-01:00" => "00:00:00Z",
      }.each_pair do |value, str|
        it "does not normalize dateTime '#{value}' by default" do
          @new.call(value, :datatype => RDF::XSD.time, :canonicalize => false).to_s.should == value
        end

        it "normalizes dateTime '#{value}'" do
          @new.call(value, :datatype => RDF::XSD.time, :canonicalize => true).to_s.should == str
        end
      end
    end
  end

  describe "#plain?" do
    literals(:all_plain_no_lang).each do |args|
      it "returns true for #{args.inspect}" do
        literal = @new.call(*args)
        literal.plain?.should be_true
      end
    end

    literals(:all_plain_lang, :all_native, :all_xml).each do |args|
      it "returns false for #{args.inspect}" do
        literal = @new.call(*args)
        literal.plain?.should be_false
      end
    end
  end

  describe "#language" do
    literals(:all_plain_no_lang, :all_native, :all_xml).each do |args|
      it "returns nil for #{args.inspect}" do
        literal = @new.call(*args)
        literal.language.should be_nil
      end
    end

    literals(:all_plain_lang).each do |args|
      it "returns language for #{args.inspect}" do
        literal = @new.call(*args)
        literal.language.should == :en
      end
    end
  end

  describe "#datatype" do
    literals(:all_plain).each do |args|
      it "returns nil for #{args.inspect}" do
        literal = @new.call(*args)
        literal.datatype.should be_nil
      end
    end

    {
      123 => "integer",
      true => "boolean",
      false => "boolean",
      9223372036854775807 => "integer",
      3.1415 => "double",
      Date.new(2010) => "date",
      DateTime.new(2011) => "dateTime",
      Time.parse("01:02:03Z") => "time"
    }.each_pair do |value, type|
      it "returns xsd.#{type} for #{value.inspect} #{value.class}" do
        @new.call(value).datatype.should == XSD[type]
      end
    end
    
    literals(:all_xml).each do |args|
      it "returns datatype for #{args.inspect}" do
        literal = @new.call(*args)
        literal.datatype.should == RDF.XMLLiteral
      end
    end
  end

 describe "#typed?" do
   literals(:all_plain).each do |args|
     it "returns false for #{args.inspect}" do
       literal = @new.call(*args)
       literal.typed?.should be_false
     end
   end

   literals(:all_native, :all_xml).each do |args|
     it "returns true for #{args.inspect}" do
       literal = @new.call(*args)
       literal.typed?.should be_true
     end
   end
 end

  describe "#==" do
    literals(:all_plain).each do |args|
      it "returns true for #{args.inspect}" do
        literal = @new.call(*args)
        literal.should == @new.call(*args)
        literal.should eql(@new.call(*args))
      end
    end

    literals(:all_plain_no_lang).each do |args|
      it "returns true for value of #{args.inspect}" do
        literal = @new.call(*args)
        literal.should == literal.value
        literal.should eql(@new.call(*args))
      end
    end

    literals(:all_plain_lang).each do |args|
      it "returns false for value of #{args.inspect}" do
        literal = @new.call(*args)
        literal.should_not == literal.value
        literal.should_not eql(literal.value)
      end
    end

    literals(:all_native, :all_xml).each do |args|
      it "returns true for #{args.inspect}" do
        literal = @new.call(*args)
        literal.should == @new.call(*args)
        literal.should eql(@new.call(*args))
      end

      it "returns false for value of #{args.inspect}" do
        literal = @new.call(*args)
        literal.should_not == literal.value
        literal.should_not eql(literal.value)
      end
    end
  end
  
  describe "#to_s" do
    literals(:all_plain).each do |args|
      it "returns value for #{args.inspect}" do
        literal = @new.call(*args)
        literal.to_s.should eql(literal.value)
      end
    end

    {
      literal(:int)      => "123",
      literal(:true)     => "true",
      literal(:false)    => "false",
      literal(:long)     => "9223372036854775807",
      literal(:double)   => "3.1415",
      literal(:date)     => "2010-01-01Z",
      literal(:datetime) => "2011-01-01T00:00:00Z",
      literal(:time)     => "01:02:03Z"
    }.each_pair do |args, rep|
      it "returns #{rep} for #{args.inspect}" do
        literal = @new.call(*args)
        literal.to_s.should eql(rep)
      end
    end
    
    {
      literal(:xml_no_ns)   => %("foo <sup>bar</sup> baz!"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>),
      literal(:xml_ns)      => %("foo <sup>bar</sup> baz!"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>),
      literal(:xml_ns_lang) => %("foo <sup xml:lang=\\"fr\\">bar</sup> baz!"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>),
      literal(:xml_lang_em) => %("foo <sup xml:lang=\\"fr\\">bar</sup><sub xml:lang=\\"en\\">baz</sub>"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>),
      literal(:xml_def_ns)  => %("foo <sup xmlns=\\"http://purl.org/dc/terms/\\">bar</sup> baz!"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>),
      literal(:xml_ns2)     => %(fixme),
    }.each_pair do |args, rep|
      it "returns n3 rep for #{args.inspect}" do
        literal = @new.call(*args)
        pending {literal.to_s.should == rep}
      end
    end
  end
  
  describe "#object" do
    literals(:all_plain).each do |args|
      it "returns value for #{args.inspect}" do
        literal = @new.call(*args)
        literal.object.should eql(literal.value)
      end
    end

    {
      literal(:int)      => 123,
      literal(:true)     => true,
      literal(:false)    => false,
      literal(:long)     => 9223372036854775807,
      literal(:double)   => 3.1415,
      literal(:date)     => Date.new(2010),
      literal(:datetime) => DateTime.new(2011),
      literal(:time)     => Time.parse('01:02:03Z')
    }.each_pair do |args, value|
      it "returns object for #{args.inspect}" do
        literal = @new.call(*args)
        literal.object.should eql(value)
      end
    end
  end
  
  describe "#anonymous?" do
    it "returns false" do
      @new.call("").anonymous?.should be_false
    end
  end

  describe "#valid?" do
    # Boolean
    {
      "true"  => "true",
      "false" => "false",
      "tRuE"  => "true",
      "FaLsE" => "false",
      "1"     => "true",
      "0"     => "false",
    }.each_pair do |value, str|
      it "validates boolean '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.boolean).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.boolean).invalid?.should be_false
      end
    end

    # Integer
    {
      "01" => "1",
      "1"  => "1",
      "-1" => "-1",
      "+1" => "1",
    }.each_pair do |value, str|
      it "validates integer '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.integer).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.integer).invalid?.should be_false
      end
    end

    # Decimal
    {
      "1"                              => "1.0",
      "-1"                             => "-1.0",
      "1."                             => "1.0",
      "1.0"                            => "1.0",
      "1.00"                           => "1.0",
      "+001.00"                        => "1.0",
      "123.456"                        => "123.456",
      "2.345"                          => "2.345",
      "1.000000000"                    => "1.0",
      "2.3"                            => "2.3",
      "2.234000005"                    => "2.234000005",
      "2.2340000000000005"             => "2.2340000000000005",
      "2.23400000000000005"            => "2.234",
      "2.23400000000000000000005"      => "2.234",
      "1.2345678901234567890123457890" => "1.2345678901234567",
    }.each_pair do |value, str|
      it "validates decimal '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.decimal).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.decimal).invalid?.should be_false
      end
    end
  
    # Double
    {
      "1"         => "1.0E0",
      "-1"        => "-1.0E0",
      "+01.000"   => "1.0E0",
      #"1."        => "1.0E0",
      "1.0"       => "1.0E0",
      "123.456"   => "1.23456E2",
      "1.0e+1"    => "1.0E1",
      "1.0e-10"   => "1.0E-10",
      "123.456e4" => "1.23456E6",
    }.each_pair do |value, str|
      it "validates double '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.double).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.double).invalid?.should be_false
      end
    end

    # DateTime
    {
      "2010-01-01T00:00:00Z"      => "2010-01-01T00:00:00Z",
      "2010-01-01T00:00:00.0000Z" => "2010-01-01T00:00:00Z",
      "2010-01-01T00:00:00"       => "2010-01-01T00:00:00Z",
      "2010-01-01T00:00:00+00:00" => "2010-01-01T00:00:00Z",
      "2010-01-01T01:00:00+01:00" => "2010-01-01T01:00:00+01:00",
      "2009-12-31T23:00:00-01:00" => "2009-12-31T23:00:00-01:00",
      "-2010-01-01T00:00:00Z"     => "-2010-01-01T00:00:00Z",
    }.each_pair do |value, str|
      it "validates dateTime '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.dateTime).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.dateTime).invalid?.should be_false
      end
    end

    # Date
    {
      "2010-01-01Z"      => "2010-01-01Z",
      "2010-01-01"       => "2010-01-01Z",
      "2010-01-01+00:00" => "2010-01-01Z",
      "2010-01-01+01:00" => "2010-01-01Z",
      "2009-12-31-01:00" => "2009-12-31Z",
      "-2010-01-01Z"     => "-2010-01-01Z",
    }.each_pair do |value, str|
      it "validates date '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.date).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.date).invalid?.should be_false
      end
    end

    # Time
    {
      "00:00:00Z"      => "00:00:00Z",
      "00:00:00.0000Z" => "00:00:00Z",
      "00:00:00"       => "00:00:00Z",
      "00:00:00+00:00" => "00:00:00Z",
      "01:00:00+01:00" => "00:00:00Z",
      "23:00:00-01:00" => "00:00:00Z",
    }.each_pair do |value, str|
      it "validates time '#{value}'" do
        @new.call(value, :datatype => RDF::XSD.time).valid?.should be_true
        @new.call(value, :datatype => RDF::XSD.time).invalid?.should be_false
      end
    end
  end

  describe "#invalid?" do
    {
      "foo"                    => RDF::XSD.boolean,
      "xyz"                    => RDF::XSD.integer,
      "12xyz"                  => RDF::XSD.integer,
      "12.xyz"                 => RDF::XSD.decimal,
      "xy.z"                   => RDF::XSD.double,
      "+1.0z"                  => RDF::XSD.double,

      "+2010-01-01T00:00:00Z"  => RDF::XSD.dateTime,
      "2010-01-01T00:00:00FOO" => RDF::XSD.dateTime,
      "02010-01-01T00:00:00"   => RDF::XSD.dateTime,
      "2010-01-01"             => RDF::XSD.dateTime,
      "2010-1-1T00:00:00"      => RDF::XSD.dateTime,
      "0000-01-01T00:00:00"    => RDF::XSD.dateTime,

      "+2010-01-01Z"           => RDF::XSD.date,
      "2010-01-01TFOO"         => RDF::XSD.date,
      "02010-01-01"            => RDF::XSD.date,
      "2010-1-1"               => RDF::XSD.date,
      "0000-01-01"             => RDF::XSD.date,

      "+00:00:00Z"             => RDF::XSD.time,
      "-00:00:00Z"             => RDF::XSD.time,
    }.each_pair do |value, datatype|
      it "does not validate for '#{value}'" do
        @new.call(value, :datatype => datatype).invalid?.should be_true
        @new.call(value, :datatype => datatype).valid?.should be_false
      end
    end
  end
end

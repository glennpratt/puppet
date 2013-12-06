require 'spec_helper'
require 'puppet/pops'

describe 'The type calculator' do
  let(:calculator) {  Puppet::Pops::Types::TypeCalculator.new() }

  def int_range(from, to)
   t = Puppet::Pops::Types::PIntegerType.new
   t.from = from
   t.to = to
   t
  end

  def pattern_t(*patterns)
    Puppet::Pops::Types::TypeFactory.pattern(*patterns)
  end

  def string_t(*strings)
    Puppet::Pops::Types::TypeFactory.string(*strings)
  end

  def enum_t(*strings)
    Puppet::Pops::Types::TypeFactory.enum(*strings)
  end

  def variant_t(*types)
    Puppet::Pops::Types::TypeFactory.variant(*types)
  end

  def integer_t()
    Puppet::Pops::Types::TypeFactory.integer()
  end

  def array_t(t)
    Puppet::Pops::Types::TypeFactory.array_of(t)
  end

  def types
    Puppet::Pops::Types
  end

  shared_context "types_setup" do

    def all_types
      [ Puppet::Pops::Types::PObjectType,
        Puppet::Pops::Types::PNilType,
        Puppet::Pops::Types::PDataType,
        Puppet::Pops::Types::PLiteralType,
        Puppet::Pops::Types::PStringType,
        Puppet::Pops::Types::PNumericType,
        Puppet::Pops::Types::PIntegerType,
        Puppet::Pops::Types::PFloatType,
        Puppet::Pops::Types::PRegexpType,
        Puppet::Pops::Types::PBooleanType,
        Puppet::Pops::Types::PCollectionType,
        Puppet::Pops::Types::PArrayType,
        Puppet::Pops::Types::PHashType,
        Puppet::Pops::Types::PRubyType,
        Puppet::Pops::Types::PHostClassType,
        Puppet::Pops::Types::PResourceType,
        Puppet::Pops::Types::PPatternType,
        Puppet::Pops::Types::PEnumType,
        Puppet::Pops::Types::PVariantType,
      ]
    end

    def literal_types
      # PVariantType is also literal, if its types are all Literal
      [
        Puppet::Pops::Types::PLiteralType,
        Puppet::Pops::Types::PStringType,
        Puppet::Pops::Types::PNumericType,
        Puppet::Pops::Types::PIntegerType,
        Puppet::Pops::Types::PFloatType,
        Puppet::Pops::Types::PRegexpType,
        Puppet::Pops::Types::PBooleanType,
        Puppet::Pops::Types::PPatternType,
        Puppet::Pops::Types::PEnumType,
      ]
    end

    def numeric_types
      # PVariantType is also numeric, if its types are all numeric
      [
        Puppet::Pops::Types::PNumericType,
        Puppet::Pops::Types::PIntegerType,
        Puppet::Pops::Types::PFloatType,
      ]
    end

    def string_types
      # PVariantType is also string type, if its types are all compatible
      [
        Puppet::Pops::Types::PStringType,
        Puppet::Pops::Types::PPatternType,
        Puppet::Pops::Types::PEnumType,
      ]
    end

    def collection_types
      # PVariantType is also string type, if its types are all compatible
      [
        Puppet::Pops::Types::PCollectionType,
        Puppet::Pops::Types::PHashType,
        Puppet::Pops::Types::PArrayType,
      ]
    end

    def data_compatible_types
      literal_types + [Puppet::Pops::Types::PHashType, Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PDataType]
    end
  end

  context 'when inferring ruby' do

    it 'fixnum translates to PIntegerType' do
      calculator.infer(1).class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'large fixnum (or bignum depending on architecture) translates to PIntegerType' do
      calculator.infer(2**33).class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'float translates to PFloatType' do
      calculator.infer(1.3).class.should == Puppet::Pops::Types::PFloatType
    end

    it 'string translates to PStringType' do
      calculator.infer('foo').class.should == Puppet::Pops::Types::PStringType
    end

    it 'inferred string type knows the string value' do
      t = calculator.infer('foo')
      t.class.should == Puppet::Pops::Types::PStringType
      t.values.should == ['foo']
    end

    it 'boolean true translates to PBooleanType' do
      calculator.infer(true).class.should == Puppet::Pops::Types::PBooleanType
    end

    it 'boolean false translates to PBooleanType' do
      calculator.infer(false).class.should == Puppet::Pops::Types::PBooleanType
    end

    it 'regexp translates to PRegexpType' do
      calculator.infer(/^a regular expression$/).class.should == Puppet::Pops::Types::PRegexpType
    end

    it 'nil translates to PNilType' do
      calculator.infer(nil).class.should == Puppet::Pops::Types::PNilType
    end

    it 'an instance of class Foo translates to PRubyType[Foo]' do
      class Foo
      end

      t = calculator.infer(Foo.new)
      t.class.should == Puppet::Pops::Types::PRubyType
      t.ruby_class.should == 'Foo'
    end

    context 'array' do
      it 'translates to PArrayType' do
        calculator.infer([1,2]).class.should == Puppet::Pops::Types::PArrayType
      end

      it 'with fixnum values translates to PArrayType[PIntegerType]' do
        calculator.infer([1,2]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'with 32 and 64 bit integer values translates to PArrayType[PIntegerType]' do
        calculator.infer([1,2**33]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'Range of integer values are computed' do
        t = calculator.infer([-3,0,42]).element_type
        t.class.should == Puppet::Pops::Types::PIntegerType
        t.from.should == -3
        t.to.should == 42
      end

      it "Compound string values are computed" do
        t = calculator.infer(['a','b', 'c']).element_type
        t.class.should == Puppet::Pops::Types::PStringType
        t.values.should == ['a', 'b', 'c']
      end

      it 'with fixnum and float values translates to PArrayType[PNumericType]' do
        calculator.infer([1,2.0]).element_type.class.should == Puppet::Pops::Types::PNumericType
      end

      it 'with fixnum and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with float and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1.0,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with fixnum, float, and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1, 2.0,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with fixnum and regexp values translates to PArrayType[PLiteralType]' do
        calculator.infer([1, /two/]).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with string and regexp values translates to PArrayType[PLiteralType]' do
        calculator.infer(['one', /two/]).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with string and symbol values translates to PArrayType[PObjectType]' do
        calculator.infer(['one', :two]).element_type.class.should == Puppet::Pops::Types::PObjectType
      end

      it 'with fixnum and nil values translates to PArrayType[PIntegerType]' do
        calculator.infer([1, nil]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'with arrays of string values translates to PArrayType[PArrayType[PStringType]]' do
        et = calculator.infer([['first' 'array'], ['second','array']])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with array of string values and array of fixnums translates to PArrayType[PArrayType[PLiteralType]]' do
        et = calculator.infer([['first' 'array'], [1,2]])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with hashes of string values translates to PArrayType[PHashType[PStringType]]' do
        et = calculator.infer([{:first => 'first', :second => 'second' }, {:first => 'first', :second => 'second' }])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PHashType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with hash of string values and hash of fixnums translates to PArrayType[PHashType[PLiteralType]]' do
        et = calculator.infer([{:first => 'first', :second => 'second' }, {:first => 1, :second => 2 }])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PHashType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PLiteralType
      end
    end

    context 'hash' do
      it 'translates to PHashType' do
        calculator.infer({:first => 1, :second => 2}).class.should == Puppet::Pops::Types::PHashType
      end

      it 'with symbolic keys translates to PHashType[PRubyType[Symbol],value]' do
        k = calculator.infer({:first => 1, :second => 2}).key_type
        k.class.should == Puppet::Pops::Types::PRubyType
        k.ruby_class.should == 'Symbol'
      end

      it 'with string keys translates to PHashType[PStringType,value]' do
        calculator.infer({'first' => 1, 'second' => 2}).key_type.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with fixnum values translates to PHashType[key,PIntegerType]' do
        calculator.infer({:first => 1, :second => 2}).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end
    end

  end

  context 'patterns' do
    it "constructs a PPatternType" do
      t = pattern_t('a(b)c')
      t.class.should == Puppet::Pops::Types::PPatternType
      t.patterns.size.should == 1
      t.patterns[0].class.should == Puppet::Pops::Types::PRegexpType
      t.patterns[0].pattern.should == 'a(b)c'
      t.patterns[0].regexp.match('abc')[1].should == 'b'
    end

    it "constructs a PStringType with multiple strings" do
      t = string_t('a', 'b', 'c', 'abc')
      t.values.should == ['a', 'b', 'c', 'abc']
    end
  end

  # Deal with cases not covered by computing common type
  context 'when computing common type' do
    it 'computes given resource type commonality' do
      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'File'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'File'
      r2.title = '/tmp/foo'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r1.title = '/tmp/foo'
      calculator.string(calculator.common_type(r1, r2)).should == "File['/tmp/foo']"

      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r1.title = '/tmp/bar'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'Package'
      r2.title = 'apache'
      calculator.string(calculator.common_type(r1, r2)).should == "Resource"
    end

    it 'computes given hostclass type commonality' do
      r1 = Puppet::Pops::Types::PHostClassType.new()
      r1.class_name = 'foo'
      r2 = Puppet::Pops::Types::PHostClassType.new()
      r2.class_name = 'foo'
      calculator.string(calculator.common_type(r1, r2)).should == "Class[foo]"

      r2 = Puppet::Pops::Types::PHostClassType.new()
      r2.class_name = 'bar'
      calculator.string(calculator.common_type(r1, r2)).should == "Class"

      r2 = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(calculator.common_type(r1, r2)).should == "Class"

      r1 = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(calculator.common_type(r1, r2)).should == "Class"
    end

    it 'computes pattern commonality' do
      t1 = pattern_t('abc')
      t2 = pattern_t('xyz')
      common_t = calculator.common_type(t1,t2)
      common_t.class.should == Puppet::Pops::Types::PPatternType
      common_t.patterns.map { |pr| pr.pattern }.should == ['abc', 'xyz']
      calculator.string(common_t).should == "Pattern[/abc/, /xyz/]"
    end

    it 'computes enum commonality to value set diff' do
      t1 = enum_t('a', 'b', 'c')
      t2 = enum_t('x', 'y', 'z')
      common_t = calculator.common_type(t1, t2)
      common_t.should == enum_t('a', 'b', 'c', 'x', 'y', 'z')
    end

    it 'computed variant commonality to type union' do
      a_t1 = integer_t()
      a_t2 = string_t()
      v_a = variant_t(a_t1, a_t2)
      b_t1 = enum_t('a')
      v_b = variant_t(b_t1)
      common_t = calculator.common_type(v_a, v_b)
      common_t.class.should == Puppet::Pops::Types::PVariantType
      Set.new(common_t.types).should  == Set.new([a_t1, a_t2, b_t1])
    end
  end

  context 'computes assignability' do
    include_context "types_setup"

    context "for Object, such that" do
      it 'all types are assignable to Object' do
        t = Puppet::Pops::Types::PObjectType.new()
        all_types.each { |t2| t2.new.should be_assignable_to(t) }
      end

      it 'Object is not assignable to anything but Object' do
        tested_types = all_types() - [Puppet::Pops::Types::PObjectType]
        t = Puppet::Pops::Types::PObjectType.new()
        tested_types.each { |t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Data, such that" do
      it 'all literals + array and hash are assignable to Data' do
        t = Puppet::Pops::Types::PDataType.new()
        data_compatible_types.each { |t2| t2.new.should be_assignable_to(t) }
      end

      it 'a Variant of literal, hash, or array is assignable to Data' do
        t = Puppet::Pops::Types::PDataType.new()
        data_compatible_types.each { |t2| variant_t(t2.new).should be_assignable_to(t) }
      end

      it 'Data is not assignable to any of its subtypes' do
        t = Puppet::Pops::Types::PDataType.new()
        types_to_test = data_compatible_types- [Puppet::Pops::Types::PDataType]
        types_to_test.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Data is not assignable to a Variant of Data subtype' do
        t = Puppet::Pops::Types::PDataType.new()
        types_to_test = data_compatible_types- [Puppet::Pops::Types::PDataType]
        types_to_test.each { |t2| t.should_not be_assignable_to(variant_t(t2.new)) }
      end

      it 'Data is not assignable to any disjunct type' do
        tested_types = all_types - [Puppet::Pops::Types::PObjectType, Puppet::Pops::Types::PDataType] - literal_types
        t = Puppet::Pops::Types::PDataType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Literal, such that" do
      it "all literals are assignable to Literal" do
        t = Puppet::Pops::Types::PLiteralType.new()
        literal_types.each {|t2| t2.new.should be_assignable_to(t) }
      end

      it 'Literal is not assignable to any of its subtypes' do
        t = Puppet::Pops::Types::PLiteralType.new() 
        types_to_test = literal_types - [Puppet::Pops::Types::PLiteralType]
        types_to_test.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Literal is not assignable to any disjunct type' do
        tested_types = all_types - [Puppet::Pops::Types::PObjectType, Puppet::Pops::Types::PDataType] - literal_types
        t = Puppet::Pops::Types::PLiteralType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Numeric, such that" do
      it "all numerics are assignable to Numeric" do
        t = Puppet::Pops::Types::PNumericType.new()
        numeric_types.each {|t2| t2.new.should be_assignable_to(t) }
      end

      it 'Numeric is not assignable to any of its subtypes' do
        t = Puppet::Pops::Types::PNumericType.new()
        types_to_test = numeric_types - [Puppet::Pops::Types::PNumericType]
        types_to_test.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Numeric is not assignable to any disjunct type' do
        tested_types = all_types - [
          Puppet::Pops::Types::PObjectType,
          Puppet::Pops::Types::PDataType,
          Puppet::Pops::Types::PLiteralType,
          ] - numeric_types
        t = Puppet::Pops::Types::PNumericType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Collection, such that" do
      it "all collections are assignable to Collection" do
        t = Puppet::Pops::Types::PCollectionType.new()
        collection_types.each {|t2| t2.new.should be_assignable_to(t) }
      end

      it 'Collection is not assignable to any of its subtypes' do
        t = Puppet::Pops::Types::PCollectionType.new()
        types_to_test = collection_types - [Puppet::Pops::Types::PCollectionType]
        types_to_test.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Collection is not assignable to any disjunct type' do
        tested_types = all_types - [Puppet::Pops::Types::PObjectType] - collection_types
        t = Puppet::Pops::Types::PCollectionType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Array, such that" do
      it "Array is not assignable to any other Collection type" do
        t = Puppet::Pops::Types::PArrayType.new()
        tested_types = collection_types - [
          Puppet::Pops::Types::PCollectionType,
          Puppet::Pops::Types::PArrayType]
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Array is not assignable to any disjunct type' do
        tested_types = all_types - [
          Puppet::Pops::Types::PObjectType,
          Puppet::Pops::Types::PObjectType,
          Puppet::Pops::Types::PDataType] - collection_types
        t = Puppet::Pops::Types::PArrayType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end

    context "for Hash, such that" do
      it "Hash is not assignable to any other Collection type" do
        t = Puppet::Pops::Types::PHashType.new()
        tested_types = collection_types - [
          Puppet::Pops::Types::PCollectionType,
          Puppet::Pops::Types::PHashType]
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end

      it 'Hash is not assignable to any disjunct type' do
        tested_types = all_types - [
          Puppet::Pops::Types::PObjectType,
          Puppet::Pops::Types::PObjectType,
          Puppet::Pops::Types::PDataType] - collection_types
        t = Puppet::Pops::Types::PHashType.new()
        tested_types.each {|t2| t.should_not be_assignable_to(t2.new) }
      end
    end


    it 'should recognize mapped ruby types' do
      { Integer    => Puppet::Pops::Types::PIntegerType.new,
        Fixnum     => Puppet::Pops::Types::PIntegerType.new,
        Bignum     => Puppet::Pops::Types::PIntegerType.new,
        Float      => Puppet::Pops::Types::PFloatType.new,
        Numeric    => Puppet::Pops::Types::PNumericType.new,
        NilClass   => Puppet::Pops::Types::PNilType.new,
        TrueClass  => Puppet::Pops::Types::PBooleanType.new,
        FalseClass => Puppet::Pops::Types::PBooleanType.new,
        String     => Puppet::Pops::Types::PStringType.new,
        Regexp     => Puppet::Pops::Types::PRegexpType.new,
        Regexp     => Puppet::Pops::Types::PRegexpType.new,
        Array      => Puppet::Pops::Types::TypeFactory.array_of_data(),
        Hash       => Puppet::Pops::Types::TypeFactory.hash_of_data()
      }.each do |ruby_type, puppet_type |
          ruby_type.should be_assignable_to(puppet_type)
      end
    end

    context 'when dealing with integer ranges' do
      it 'should accept an equal range' do
        calculator.assignable?(int_range(2,5), int_range(2,5)).should == true
      end

      it 'should accept an equal reverse range' do
        calculator.assignable?(int_range(2,5), int_range(5,2)).should == true
      end

      it 'should accept a narrower range' do
        calculator.assignable?(int_range(2,10), int_range(3,5)).should == true
      end

      it 'should accept a narrower reverse range' do
        calculator.assignable?(int_range(2,10), int_range(5,3)).should == true
      end

      it 'should reject a wider range' do
        calculator.assignable?(int_range(3,5), int_range(2,10)).should == false
      end

      it 'should reject a wider reverse range' do
        calculator.assignable?(int_range(3,5), int_range(10,2)).should == false
      end

      it 'should reject a partially overlapping range' do
        calculator.assignable?(int_range(3,5), int_range(2,4)).should == false
        calculator.assignable?(int_range(3,5), int_range(4,6)).should == false
      end

      it 'should reject a partially overlapping reverse range' do
        calculator.assignable?(int_range(3,5), int_range(4,2)).should == false
        calculator.assignable?(int_range(3,5), int_range(6,4)).should == false
      end
    end

    context 'when dealing with patterns' do
      it 'should accept a string matching a pattern' do
        p_t = pattern_t('abc')
        p_s = string_t('XabcY')
        calculator.assignable?(p_t, p_s).should == true
      end

      it 'should accept a string matching all patterns' do
        p_t = pattern_t('abc', 'ab', 'c')
        p_s = string_t('XabcY')
        calculator.assignable?(p_t, p_s).should == true
      end

      it 'should accept multiple strings if they all match all patterns' do
        p_t = pattern_t('abc', 'ab', 'c')
        p_s = string_t('XabcY', 'abcde')
        calculator.assignable?(p_t, p_s).should == true
      end

      it 'should reject a string not matching all patterns' do
        p_t = pattern_t('abc', 'ab', 'c', 'q')
        p_s = string_t('XqqqY')
        calculator.assignable?(p_t, p_s).should == false
      end

      it 'should reject multiple strings if not all match all patterns' do
        p_t = pattern_t('abc', 'ab', 'c', 'q')
        p_s = string_t('abc', 'XqqqY')
        calculator.assignable?(p_t, p_s).should == false
      end
    end

    it 'should recognize ruby type inheritance' do
      class Foo
      end

      class Bar < Foo
      end

      fooType = calculator.infer(Foo.new)
      barType = calculator.infer(Bar.new)

      calculator.assignable?(fooType, fooType).should == true
      calculator.assignable?(Foo, fooType).should == true

      calculator.assignable?(fooType, barType).should == true
      calculator.assignable?(Foo, barType).should == true

      calculator.assignable?(barType, fooType).should == false
      calculator.assignable?(Bar, fooType).should == false
    end

    it "should allow host class with same name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      calculator.assignable?(hc1, hc2).should == true
    end

    it "should allow host class with name assigned to hostclass without name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class()
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      calculator.assignable?(hc1, hc2).should == true
    end

    it "should reject host classes with different names" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('another_name')
      calculator.assignable?(hc1, hc2).should == false
    end

    it "should reject host classes without name assigned to host class with name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class()
      calculator.assignable?(hc1, hc2).should == false
    end

    it "should allow resource with same type_name and title" do
      r1 = Puppet::Pops::Types::TypeFactory.resource('file', 'foo')
      r2 = Puppet::Pops::Types::TypeFactory.resource('file', 'foo')
      calculator.assignable?(r1, r2).should == true
    end

    it "should allow more specific resource assignment" do
      r1 = Puppet::Pops::Types::TypeFactory.resource()
      r2 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == true
      r2 = Puppet::Pops::Types::TypeFactory.resource('file', '/tmp/foo')
      calculator.assignable?(r1, r2).should == true
      r1 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == true
    end

    it "should reject less specific resource assignment" do
      r1 = Puppet::Pops::Types::TypeFactory.resource('file', '/tmp/foo')
      r2 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == false
      r2 = Puppet::Pops::Types::TypeFactory.resource()
      calculator.assignable?(r1, r2).should == false
    end

  end

  context 'when testing if x is instance of type t' do
    it 'should consider fixnum instanceof PIntegerType' do
      calculator.instance?(Puppet::Pops::Types::PIntegerType.new(), 1) == true
    end

    it 'should consider fixnum instanceof Fixnum' do
      calculator.instance?(Fixnum, 1) == true
    end

    it 'should consider integer in range' do
      range = int_range(0,10)
      calculator.instance?(range, 1) == true
      calculator.instance?(range, 10) == true
      calculator.instance?(range, -1) == false
      calculator.instance?(range, 11) == false
    end

    it 'should consider string matching enum as instanceof' do
      enum = enum_t('XS', 'S', 'M', 'L', 'XL', '0')
      calculator.instance?(enum, 'XS')  == true
      calculator.instance?(enum, 'S')   == true
      calculator.instance?(enum, 'XXL') == false
      calculator.instance?(enum, '')    == false
      calculator.instance?(enum, '0')   == true
      calculator.instance?(enum, 0)     == false
    end

    it 'should consider array[string] as instance of Array[Enum] when strings are instance of Enum' do
      enum = enum_t('XS', 'S', 'M', 'L', 'XL', '0')
      array = array_t(enum)
      calculator.instance?(array, ['XS', 'S', 'XL'])  == true
      calculator.instance?(array, ['XS', 'S', 'XXL']) == false
    end

    it 'should consider array[mixed] as instance of Variant[mixed] when mixed types are listed in Variant' do
      enum = enum_t('XS', 'S', 'M', 'L', 'XL')
      sizes = int_range(30, 50)
      array = variant_t(enum, sizes)
      calculator.instance?(array, ['XS', 'S', 30, 50])  == true
      calculator.instance?(array, ['XS', 'S', 'XXL'])   == false
      calculator.instance?(array, ['XS', 'S', 29])      == false
    end
  end

  context 'when converting a ruby class' do
    it 'should yield \'PIntegerType\' for Integer, Fixnum, and Bignum' do
      [Integer,Fixnum,Bignum].each do |c|
        calculator.type(c).class.should == Puppet::Pops::Types::PIntegerType
      end
    end

    it 'should yield \'PFloatType\' for Float' do
      calculator.type(Float).class.should == Puppet::Pops::Types::PFloatType
    end

    it 'should yield \'PBooleanType\' for FalseClass and TrueClass' do
      [FalseClass,TrueClass].each do |c|
        calculator.type(c).class.should == Puppet::Pops::Types::PBooleanType
      end
    end

    it 'should yield \'PNilType\' for NilClass' do
      calculator.type(NilClass).class.should == Puppet::Pops::Types::PNilType
    end

    it 'should yield \'PStringType\' for String' do
      calculator.type(String).class.should == Puppet::Pops::Types::PStringType
    end

    it 'should yield \'PRegexpType\' for Regexp' do
      calculator.type(Regexp).class.should == Puppet::Pops::Types::PRegexpType
    end

    it 'should yield \'PArrayType[PDataType]\' for Array' do
      t = calculator.type(Array)
      t.class.should == Puppet::Pops::Types::PArrayType
      t.element_type.class.should == Puppet::Pops::Types::PDataType
    end

    it 'should yield \'PHashType[PLiteralType,PDataType]\' for Hash' do
      t = calculator.type(Hash)
      t.class.should == Puppet::Pops::Types::PHashType
      t.key_type.class.should == Puppet::Pops::Types::PLiteralType
      t.element_type.class.should == Puppet::Pops::Types::PDataType
    end
  end

  context 'when representing the type as string' do
    it 'should yield \'Type\' for PType' do
      calculator.string(Puppet::Pops::Types::PType.new()).should == 'Type'
    end

    it 'should yield \'Object\' for PObjectType' do
      calculator.string(Puppet::Pops::Types::PObjectType.new()).should == 'Object'
    end

    it 'should yield \'Literal\' for PLiteralType' do
      calculator.string(Puppet::Pops::Types::PLiteralType.new()).should == 'Literal'
    end

    it 'should yield \'Boolean\' for PBooleanType' do
      calculator.string(Puppet::Pops::Types::PBooleanType.new()).should == 'Boolean'
    end

    it 'should yield \'Data\' for PDataType' do
      calculator.string(Puppet::Pops::Types::PDataType.new()).should == 'Data'
    end

    it 'should yield \'Numeric\' for PNumericType' do
      calculator.string(Puppet::Pops::Types::PNumericType.new()).should == 'Numeric'
    end

    it 'should yield \'Integer\' and from/to for PIntegerType' do
      int_T = Puppet::Pops::Types::PIntegerType
      calculator.string(int_T.new()).should == 'Integer'
      int = int_T.new()
      int.from = 1
      int.to = 1
      calculator.string(int).should == 'Integer[1]'
      int = int_T.new()
      int.from = 1
      int.to = 2
      calculator.string(int).should == 'Integer[1, 2]'
      int = int_T.new()
      int.from = nil
      int.to = 2
      calculator.string(int).should == 'Integer[default, 2]'
      int = int_T.new()
      int.from = 2
      int.to = nil
      calculator.string(int).should == 'Integer[2, default]'
    end

    it 'should yield \'Float\' for PFloatType' do
      calculator.string(Puppet::Pops::Types::PFloatType.new()).should == 'Float'
    end

    it 'should yield \'Regexp\' for PRegexpType' do
      calculator.string(Puppet::Pops::Types::PRegexpType.new()).should == 'Regexp'
    end

    it 'should yield \'Regexp[/pat/]\' for parameterized PRegexpType' do
      t = Puppet::Pops::Types::PRegexpType.new()
      t.pattern = ('a/b')
      calculator.string(Puppet::Pops::Types::PRegexpType.new()).should == 'Regexp'
    end

    it 'should yield \'String\' for PStringType' do
      calculator.string(Puppet::Pops::Types::PStringType.new()).should == 'String'
    end

    it 'should yield \'String\' for PStringType with multiple values' do
      calculator.string(string_t('a', 'b', 'c')).should == 'String'
    end

    it 'should yield \'Array[Integer]\' for PArrayType[PIntegerType]' do
      t = Puppet::Pops::Types::PArrayType.new()
      t.element_type = Puppet::Pops::Types::PIntegerType.new()
      calculator.string(t).should == 'Array[Integer]'
    end

    it 'should yield \'Hash[String, Integer]\' for PHashType[PStringType, PIntegerType]' do
      t = Puppet::Pops::Types::PHashType.new()
      t.key_type = Puppet::Pops::Types::PStringType.new()
      t.element_type = Puppet::Pops::Types::PIntegerType.new()
      calculator.string(t).should == 'Hash[String, Integer]'
    end

    it "should yield 'Class' for a PHostClassType" do
      t = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(t).should == 'Class'
    end

    it "should yield 'Class[x]' for a PHostClassType[x]" do
      t = Puppet::Pops::Types::PHostClassType.new()
      t.class_name = 'x'
      calculator.string(t).should == 'Class[x]'
    end

    it "should yield 'Resource' for a PResourceType" do
      t = Puppet::Pops::Types::PResourceType.new()
      calculator.string(t).should == 'Resource'
    end

    it 'should yield \'File\' for a PResourceType[\'File\']' do
      t = Puppet::Pops::Types::PResourceType.new()
      t.type_name = 'File'
      calculator.string(t).should == 'File'
    end

    it "should yield 'File['/tmp/foo']' for a PResourceType['File', '/tmp/foo']" do
      t = Puppet::Pops::Types::PResourceType.new()
      t.type_name = 'File'
      t.title = '/tmp/foo'
      calculator.string(t).should == "File['/tmp/foo']"
    end

    it "should yield 'Enum[s,...]' for a PEnumType[s,...]" do
      t = enum_t('a', 'b', 'c')
      calculator.string(t).should == "Enum['a', 'b', 'c']"
    end

    it "should yield 'Pattern[/pat/,...]' for a PPatternType['pat',...]" do
      t = pattern_t('a')
      t2 = pattern_t('a', 'b', 'c')
      calculator.string(t).should == "Pattern[/a/]"
      calculator.string(t2).should == "Pattern[/a/, /b/, /c/]"
    end

    it "should escape special characters in the string for a PPatternType['pat',...]" do
      t = pattern_t('a/b')
      calculator.string(t).should == "Pattern[/a\\/b/]"
    end

    it "should yield 'Variant[t1,t2,...]' for a PVariantType[t1, t2,...]" do
      t1 = string_t()
      t2 = integer_t()
      t3 = pattern_t('a')
      t = variant_t(t1, t2, t3)
      calculator.string(t).should == "Variant[String, Integer, Pattern[/a/]]"
    end
  end

  context 'when processing meta type' do
    it 'should infer PType as the type of all other types' do
      ptype = Puppet::Pops::Types::PType
      calculator.infer(Puppet::Pops::Types::PNilType.new()       ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PDataType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PLiteralType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PStringType.new()    ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PNumericType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PIntegerType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PFloatType.new()     ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PRegexpType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PBooleanType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PCollectionType.new()).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PArrayType.new()     ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PHashType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PRubyType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PHostClassType.new() ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PResourceType.new()  ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PEnumType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PPatternType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PVariantType.new()   ).is_a?(ptype).should() == true
    end

    it 'should infer PType as the type of all other types' do
      ptype = Puppet::Pops::Types::PType
      calculator.string(calculator.infer(Puppet::Pops::Types::PNilType.new()       )).should == "Type[Undef]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PDataType.new()      )).should == "Type[Data]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PLiteralType.new()   )).should == "Type[Literal]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PStringType.new()    )).should == "Type[String]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PNumericType.new()   )).should == "Type[Numeric]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PIntegerType.new()   )).should == "Type[Integer]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PFloatType.new()     )).should == "Type[Float]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PRegexpType.new()    )).should == "Type[Regexp]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PBooleanType.new()   )).should == "Type[Boolean]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PCollectionType.new())).should == "Type[Collection]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PArrayType.new()     )).should == "Type[Array[?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PHashType.new()      )).should == "Type[Hash[?, ?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PRubyType.new()      )).should == "Type[Ruby[?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PHostClassType.new() )).should == "Type[Class]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PResourceType.new()  )).should == "Type[Resource]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PEnumType.new()      )).should == "Type[Enum]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PVariantType.new()   )).should == "Type[Variant]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PPatternType.new()   )).should == "Type[Pattern]"
    end

    it "computes the common type of PType's type parameter" do
      int_t    = Puppet::Pops::Types::PIntegerType.new()
      string_t = Puppet::Pops::Types::PStringType.new()
      calculator.string(calculator.infer([int_t])).should == "Array[Type[Integer]]"
      calculator.string(calculator.infer([int_t, string_t])).should == "Array[Type[Literal]]"
    end

    it 'should infer PType as the type of ruby classes' do
      class Foo
      end
      [Object, Numeric, Integer, Fixnum, Bignum, Float, String, Regexp, Array, Hash, Foo].each do |c|
        calculator.infer(c).is_a?(Puppet::Pops::Types::PType).should() == true
      end
    end

    it 'should infer PType as the type of PType (meta regression short-circuit)' do
      calculator.infer(Puppet::Pops::Types::PType.new()).is_a?(Puppet::Pops::Types::PType).should() == true
    end
  end

  context "when asking for an enumerable " do
    it "should produce an enumerable for an Integer range that is not infinite" do
      t = Puppet::Pops::Types::PIntegerType.new()
      t.from = 1
      t.to = 10
      calculator.enumerable(t).respond_to?(:each).should == true
    end

    it "should not produce an enumerable for an Integer range that has an infinite side" do
      t = Puppet::Pops::Types::PIntegerType.new()
      t.from = nil
      t.to = 10
      calculator.enumerable(t).should == nil

      t = Puppet::Pops::Types::PIntegerType.new()
      t.from = 1
      t.to = nil
      calculator.enumerable(t).should == nil
    end

    it "all but Integer range are not enumerable" do
      [Object, Numeric, Float, String, Regexp, Array, Hash].each do |t|
        calculator.enumerable(calculator.type(t)).should == nil
      end
    end
  end

  matcher :be_assignable_to do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(type, actual)
    end

    failure_message_for_should do |actual|
      "#{calc.string(actual)} should be assignable to #{calc.string(type)}"
    end

    failure_message_for_should_not do |actual|
      "#{calc.string(actual)} is assignable to #{calc.string(type)} when it should not"
    end
  end

end
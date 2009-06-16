require File.dirname(__FILE__) + '/test_helper'

describe "Ar Helper" do
  include ArHelper::Sugar
  
  setup do
    create_schema
  end
  
  it "should search people" do
    @results = Person.search("jack")
    @results.should.be.instance_of Array
  end
  
  # CONTINUE HERE add 3 more test cases for different search scenarios...
  
  it "should get all people" do
    all_people = Person.find(:all)
    all(:people).should.equal all_people
  end

  it "should get recent people" do
    recent_people = Person.find(:all, :order => "created_at", :limit => 5)
    recent(:people).should.equal recent_people
  end
  
  it "should get recent people with conditions" do
    last_ten_people = Person.find(:all, :order => "created_at", :limit => 10)
    recent(:people, :limit => 10).should.equal last_ten_people
  end

  it "should fill params into a Person Object" do
    person_params = Person.to_params
    assert person_params.has_key?(:params)
    # since to_params doesn't generate attrs : id, created_at or updated_at
    params_length = Person.columns.length - 3
    person_params[:params].length.should.equal params_length
  end

  it "should get first person" do
    first_person = Person.first
    first(:person).should.equal first_person
  end

  it "should get last person" do
    last_person = Person.last
    last(:person).should.equal last_person
  end

  it "should raise error when missing attributes" do
    first(:dummy).should.be.nil
  end
  
  it "should pass a relationship and extend methods" do
    create_people_and_pencils
    recent_pencils = @new_person.pencils.find(:all, :order => "created_at", :limit => 5)
    recent_pencils.should.equal recent("@new_person.pencils")
  end
  
  it "should have duplicates for a person" do
    col = "name"
    duplicates = Person.find_by_sql "SELECT #{col}, COUNT(#{col}) AS 
                                     duplicates FROM people
                                     GROUP BY #{col} HAVING(COUNT(#{col})>1)"
    duplicates.should.equal Person.duplicates_on(col)                                 
  end
  
  it "should pass an array to find and return results" do
    create_people_and_pencils
    @all_people = Person.find(:all)
    recent(@all_people).should.equal @all_people[0..5]
  end
  
  it "should return nil if object is nil" do
    @all_people = Person.find(:all) # => there is no people 
    recent(@all_people).should.be.blank?
  end
  
  teardown do
    drop_models
  end
  
  def create_people_and_pencils
    @new_person = Person.create(Person.to_params[:params])
    @new_person.pencils.create(Pencil.to_params(:params, :remove => :person_id)[:params])
  end
end

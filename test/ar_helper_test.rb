require File.dirname(__FILE__) + '/test_helper'

describe "Ar Helper" do
  
  setup do
    create_schema
  end

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
  
  it "should have duplicates for a person" do
    col = "name"
    duplicates = Person.find_by_sql "SELECT #{col}, COUNT(#{col}) AS 
                                     duplicates FROM people
                                     GROUP BY #{col} HAVING(COUNT(#{col})>1)"
    duplicates.should.equal Person.duplicates_on(col)                                 
  end
  
  teardown do
    drop_models
  end
  
end

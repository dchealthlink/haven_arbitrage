# constants for translating mobile JSON


# this is a table of the different classes of primary key, 
# and which fieldnames correspond to each. The assumption 
# is that each fieldname is uniquely used to denote that 
# primary key.

KEY_SETTERS = {
        :'@finapp_id' =>   ["eaid"],
        :'@personid'  =>   ["eapersonid"],
        :'@id'        =>   ["insuranceid", "incomeid", "tax_no", "cross_personid"],
        :'@type'      =>   ["addresstype", "insurancetype", "incometype", "emailtype" , "numbertype"]
    }

# This is a table of mappings from mobile input JSON elements
# to the corresponding table names in the HAVEN input database
TABLENAMES = {
  Application:              "finapp_in",
  Person:                   "finapp_person_in", 
  Address:                  "finapp_person_address_in",
  Insurance:                "finapp_person_benefit_in",
  Income:                   "finapp_person_income_in",
  Deduction:                "finapp_person_deduction_in",
  TaxHousehold:             "finapp_tax_in",
  ApplicationRelationship:  "finapp_relationship_in",
  Phone:                    "finapp_person_phone_in",
  Email:                    "finapp_person_email_in"
}    
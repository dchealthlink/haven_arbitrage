require 'nokogiri'
require 'rest-client'
require 'json'
require './config/secret.rb'
require "./app/models/application_xlate.rb"
require "./app/helpers/publish_to_ea.rb"
require "./app/notifications/slack_notifier.rb"
$EA_LOG = Logger.new('./log/ea.log', 'monthly')




class EA_translate



def process(faa, path, xlate, arr, faa_id, pid, id, type, tbd)
@xlate = xlate
x = path.gsub(/.\d./, "")   #remove [1] like in path ex: /financial_assistance_application/assistance_tax_households/assistance_tax_household/assistance_tax_household_members/assistance_tax_household_member[1]
puts "path x: #{x}"
sourcetype = x.to_s.split("/")
sourcetype.delete("")
puts "#{sourcetype.inspect}"

	if sourcetype.count > 1
		sourcefield = sourcetype.delete_at(-1)
	end
 
puts "The source type:#{sourcetype.join(".")}\nThe source field:#{sourcefield}"
#record = @xlate.where(["sourcetype=? and sourcefield=? and status=?", "#{sourcetype.join(".")}", "#{sourcefield}", "A"])
record = @xlate.select {|rec| (rec.sourcetype == "#{sourcetype.join(".")}" and rec.sourcefield == "#{sourcefield}")}

	unless record.empty?
	puts "The record: #{record.inspect}"

	@sv = {}
		if record.first.siflag == "Y"
			@sv[record.first.targetfield] = strip_tag_value(faa.content)
			puts "Source value from siflag Y:#{@sv}"

		elsif record.first.siflag == "N"
			#rec = @xlate.where(["sourcetype=? and sourcefield=? and sourcevalue=?", "#{sourcetype.join(".")}", "#{sourcefield}", "#{strip_tag_value(faa.content)}"])
			rec = @xlate.select {|rec| (rec.sourcetype == "#{sourcetype.join(".")}" and rec.sourcefield == "#{sourcefield}" and rec.sourcevalue == "#{strip_tag_value(faa.content)}")}
			rec_group = rec.group_by(&:targetfield)

			rec_group.keys.each do |key|
				recx = rec_group[key].first
			
			puts "recx**: #{recx}"

			# if recx.targetvalue.include?("#")
			# 	recx_targetvalue = recx.targetvalue.split("#")[-1]
			# else
			# 	recx_targetvalue = recx.targetvalue
			# end

			@sv[recx.targetfield] = strip_tag_value(recx.targetvalue)
			#sv << recx.targetvalue #unless recx.empty?
			puts "Source value from siflag N:#{@sv}"
		    end
		end

	end


finapp_id = strip_tag_value(faa_id.content)
tablename = record.first.targettype unless record.empty?
person_id = pid
id = id
type = type
tbd = tbd
fieldname = record.first.targetfield unless record.empty?


@tablename_array << tablename if (!@tablename_array.include?(tablename) && tablename != nil)

if @sv != nil 
@sv.each do |key, value|
	if value != (nil || "")
		arr << [finapp_id, tablename, person_id, id, type, tbd, key, value]
	end
end	
end

end # process method end

def ea_payload_post(payload)
file_input_wrapper_response = RestClient.post('newsafehaven.dcmic.org/file_input_wrapper.php', payload)
$EA_LOG.info("***********************\n\n#{file_input_wrapper_response.body}\n**********************\n\n")
puts "file_input_wrapper_response: #{file_input_wrapper_response.body}"
response_hash = JSON.parse(file_input_wrapper_response.body)
puts "response_hash: #{response_hash}"
if response_hash.keys.include?("ERROR")
	Publish_EA.new(@properties.to_hash).error_intake_status(response_hash["ERROR"], "501")
	Slack_it.new.notify(response_hash["ERROR"])
elsif response_hash.keys.include?("Success")
	Slack_it.new.notify("Loaded successfully in to Finapp in tables")
	payload = {"finAppId"=>@faa_id}.to_s.gsub("=>", ":")
	puts "file_input_wrapper_response payload: #{payload}"
	finapp_system_wrapper_response = RestClient.post('newsafehaven.dcmic.org/finapp_system_wrapper.php', payload)
	$EA_LOG.info("***********************\n\n#{finapp_system_wrapper_response.body}\n**********************\n\n")
end	

end # ea_payload_post method end


def to_haven(rabbitmq_message, properties)
@properties = properties
payload_hash = translate_ea_to_haven(rabbitmq_message)
ea_payload_post(payload_hash[:payload])
end


def strip_tag_value(value)
	if value.include?("#")
		stripped_value = value.split("#")[-1]
	else
		stripped_value = value
	end
end   # strip_tag_value methods end




#****************************
def translate_ea_to_haven(ea_xml_string)

@ea_xml = Nokogiri::XML(ea_xml_string)
@ea_xml.remove_namespaces!    # to remove all namespaces from xml docs
#@xlate = Application_xlate.where(["sourcein=? and targetout=?", "ea", "haven"])
@xlate = Application_xlate.where(["sourcein=? and targetout=? and status=?", "ea", "haven", "A"]).to_a

arr = []
@tablename_array = []
faa_id = @ea_xml.at("//financial_assistance_application/id/id")
@faa_id = strip_tag_value(faa_id.content)
log_ea_intake

@ea_xml.at("//financial_assistance_application").element_children.each do |faa|        #faa and has 3 children(id, benchmark_plan, assistance_tax_households)

	puts "The tag name is: #{faa.name} and path is: #{faa.path}"

x = faa.path

process(faa, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)


#********************************Benchmark Plan start******************************
if faa.name == "benchmark_plan"
	faa.element_children.each do |bm|
		x = bm.path
		process(bm, x, @xlate, arr, faa_id, @person_id, @bm_id, nil, nil)
	
	if bm.name == "carrier"
		bm.element_children.each do |bm_carrier|
			x = bm_carrier.path
			process(bm_carrier, x, @xlate, arr, faa_id, @person_id, @bm_id, nil, nil)

			if bm_carrier.name == "id"
				bm_carrier.element_children.each do |bm_carrier_id|
				x = bm_carrier_id.path
				process(bm_carrier_id, x, @xlate, arr, faa_id, @person_id, @bm_id, nil, nil)
				end
			end
		end
	end

	if bm.name == "id"
		bm.element_children.each do |bm_id|

			if bm_id.name == "id"
				@bm_id = strip_tag_value(bm_id.content)
			end
			x = bm_id.path
			process(bm_id, x, @xlate, arr, faa_id, @person_id, @bm_id, nil, nil)
		end
	end
end
end
#****************************Benchmark Plan end**************************************

if faa.name == "assistance_tax_households"

puts "I am in assistance_tax_households block and the path: #{faa.path}"
	faa.element_children.each do |ath|    #count 1

		ath.element_children.each do |block|  #count 4 id, primary_applicant_id, assistance_tax_household_members, eligibility_determinations
		
			if block.name == "id"
			block.element_children.each do |id_block|

				if id_block.name == "id"
					@assistance_tax_household_id = strip_tag_value(id_block.content)
 				end

				x = id_block.path
				process(id_block, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
				end
			end

			if block.name == "primary_applicant_id"
				block.element_children.each do |p_app_id|
				x = p_app_id.path
				process(p_app_id, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
				end
			end

			if block.name == "assistance_tax_household_members"
				block.element_children.each do |athm|     					#children of "assistance_tax_household_members"
					athm.element_children.each do |athm_block|				#children of "assistance_tax_household_member"

						#for non block elements
						if athm_block.name == "tax_filer_type"
							x = athm_block.path
							process(athm_block, x, @xlate, arr, faa_id, @person_id, @assistance_tax_household_id, nil, nil)
							puts "The tax no is: #{@assistance_tax_household_id}"
						else
						  	x = athm_block.path
							process(athm_block, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
						 end


						if athm_block.name == "individual"			
						  athm_block.element_children.each do |individual_blocks|       #children of "individual"

						  	#for non block elements
						  	x = individual_blocks.path
							process(individual_blocks, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

							  	if individual_blocks.name == "id"
									individual_blocks.element_children.each do |individual_id|  ##children of "id block"
										x = individual_id.path
										process(individual_id, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
									end
								end	

							#*******************************Person block start ************************************

								if individual_blocks.name == "person"

									individual_blocks.element_children.each do |individual_person|    #children of person block
										puts "individual_person block name: #{individual_person.name}"
										 x = individual_person.path
										 process(individual_person, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

										individual_person.element_children.each do |person_block|
											x = person_block.path
											process(person_block, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

											if person_block.name == "id"
												@person_id = strip_tag_value(person_block.content)
											end

										end
										#*****************Addresses***********************************
											if individual_person.name == "addresses"
												individual_person.element_children.each do |address|
													address.element_children.each do |address_element|

													if address_element.name == "type"	
														@address_type = strip_tag_value(address_element.content)
													end
													x = address_element.path
											 	    process(address_element, x, @xlate, arr, faa_id, @person_id, nil, @address_type, nil)
											 		end
											 	end
											 end
										#***********Emails*****************************************

											 if individual_person.name == "emails"
												individual_person.element_children.each do |emails|
													emails.element_children.each do |email_element|

													  if email_element.name == "type"	
														@email_type = strip_tag_value(email_element.content)
													  end
													x = email_element.path
											 	    process(email_element, x, @xlate, arr, faa_id, @person_id, nil, @email_type, nil)
											 		end
											 	end
											 end
										#*********************Phones********************************

											 if individual_person.name == "phones"
												individual_person.element_children.each do |phones|
													phones.element_children.each do |phone_element|

														if phone_element.name == "type"	
														@phone_type = strip_tag_value(phone_element.content)
														end
													x = phone_element.path
											 	    process(phone_element, x, @xlate, arr, faa_id, @person_id, nil, @phone_type, nil)
											 		end
											 	end
											 end
											
										
									end		#children do block of person

								end		# if block of person
							#***************************************Person block end ***************************************

							#*********************person relationship start*********************************


								if individual_blocks.name == "person_relationships"
									individual_blocks.element_children.each do |person_relationships|  ##children of "id block"

										person_relationships.element_children.each do |person_relationship|
											if person_relationship.name == "object_individual"
											person_relationship.element_children.each do |object_individual|
												@cross_personid = strip_tag_value(object_individual.content)
												end	
											end
										end

										person_relationships.element_children.each do |person_relationship|
										
										x = person_relationship.path
										process(person_relationship, x, @xlate, arr, faa_id, @person_id, @cross_personid, nil, nil)
										
										if person_relationship.name == "subject_individual"
											person_relationship.element_children.each do |subject_individual|
												x = subject_individual.path
												process(subject_individual, x, @xlate, arr, faa_id, @person_id, @cross_personid, nil, nil)
											end	
										end


										if person_relationship.name == "object_individual"
											person_relationship.element_children.each do |object_individual|
												x = object_individual.path
												process(object_individual, x, @xlate, arr, faa_id, @person_id, @cross_personid, nil, nil)
											end	
										end


										end
									end
								end

							#**********************************person relationship end *************************

							#*********************************person demographics start*************************

							if individual_blocks.name == "person_demographics"
								individual_blocks.element_children.each do |person_demographics|
									x = person_demographics.path
									process(person_demographics, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

									if person_demographics.name == "tribal_info"
										person_demographics.element_children.each do |tribal_info|
											x = tribal_info.path
											process(tribal_info, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
										end
									end
								end
							end
									
							#*********************************person demographics end*************************

							#*********************************person health start*************************
							if individual_blocks.name == "person_health"
								individual_blocks.element_children.each do |person_health|
									x = person_health.path
									process(person_health, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
								end

							end
							#*********************************person health end*************************


						   end	# children do block of individual

						end  # if block individual

						#*********************************Immigration information start*************************
						if athm_block.name == "immigration_information"			
						  athm_block.element_children.each do |immigration_information|       #children of "individual"

						  	#for non block elements
							  	x = immigration_information.path
								process(immigration_information, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

								if immigration_information.name == "documents"
									immigration_information.element_children.each do |documents|
										x = documents.path
										process(documents, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)

								if documents.name.include?("document_")
									documents.element_children.each do |document_block|
										x = document_block.path
								        process(document_block, x, @xlate, arr, faa_id, @person_id, nil, nil, nil)
									end
								end
								end
							end
							end
						end
						#*********************************Immigration information end*************************

						#*********************************Income start*************************
						if athm_block.name == "incomes"			
						  athm_block.element_children.each do |incomes|       #children of "individual"

						  	incomes.element_children.each do |income|
						  		if income.name == "income_id"
						  			@income_id = strip_tag_value(income.content)
						  		end

						  		if income.name == "income_type"
						  			@income_type = strip_tag_value(income.content)
						  		end
						  	end

						  	incomes.element_children.each do |income|
							  	x = income.path
								process(income, x, @xlate, arr, faa_id, @person_id, @income_id, @income_type, nil)

								if income.name == "employer_address"
									income.element_children.each do |employer_address|
										x = employer_address.path
										process(employer_address, x, @xlate, arr, faa_id, @person_id, @income_id, @income_type, nil)
									end
								end
							end
						  end
						end
						#*********************************Income end*************************

						#*********************************deductions start*************************
						if athm_block.name == "deductions"			
						  athm_block.element_children.each do |deductions|       #children of "individual"

						  	deductions.element_children.each do |deduction|
						  		if deduction.name == "deduction_id"
						  			@deduction_id = strip_tag_value(deduction.content)
						  		end

						  		if deduction.name == "deduction_type"
						  			@deduction_type = strip_tag_value(deduction.content)
						  		end
						  	end

						  	deductions.element_children.each do |deduction|
							  	x = deduction.path
								process(deduction, x, @xlate, arr, faa_id, @person_id, @deduction_id, @deduction_type, nil)
							end
						  end
						end
						#*********************************deduction end*************************


						#*********************************benefits start*************************

						if athm_block.name == "benefits"	


						  athm_block.element_children.each do |benefits|       #children of "individual"

						  	benefits.element_children.each do |benefit|

						  		if benefit.name == "benefit_id"
							  	@insurance_id = strip_tag_value(benefit.content)
							  	puts "The benefit insurance ID: #{@insurance_id.inspect}**************"
							    end

						  		if benefit.name == "benefit_insurance_type"
							  	@insurance_type = strip_tag_value(benefit.content)
							  	puts "The benefit type: #{@insurance_type.inspect}**************"
							    end
							end

						  	benefits.element_children.each do |benefit|
							  	x = benefit.path
							  	puts "Benefit path: #{x}"
							  	puts "Benefit value: #{benefit.content}"
								process(benefit, x, @xlate, arr, faa_id, @person_id, @insurance_id, @insurance_type, nil)
							end
						  end
						end
						#*********************************benefits end*************************

					end		#children do block of "assistance_tax_household_member"

				end		#children do block of "assistance_tax_household_members"

			end   # if block "assistance_tax_household_members"

		end  # children do block "assistance_tax_household"

	end  # children do block "assistance_tax_households"

end # if block "assistance_tax_households"


end # Do block //financial_assistance_application"



filer_type = arr.select {|x| x[-2] == "filertype"}

filer_type.each {|x| x[1] = "finapp_tax_in" }

tax_in_reject =[]

arr.delete_if {|x| tax_in_reject << x if x[1] == "finapp_tax_in" }
filer_type.delete_if {|x| x[3]==nil}

filer_type.uniq.each {|x| arr << x}

#add rabbitmq headers to finapp in fields
arr.concat(add_headers_to_finapp_in)

$EA_LOG.info("***********************\n\nThe Holy moly Big Array:\n #{arr.inspect}\n**********************\n\n")



@tablename_array.insert(0, "finapp_header")  #for storing EA headers in finapp_header table
@tablename_array.each do |tn|

@table_arr = arr.select do |value|
	value[1] == tn
end


if !@table_arr.empty?
str = @table_arr.map {|x| x.join("|")}.join("|]") + "|]"
@payload_str = @payload_str.to_s + str 
end
end

@post_payload = @payload_str + "\n\n" 

$EA_LOG.info("***********************\n\npayload:\n #{@post_payload}\n**********************\n\n")

translated_hash = {}
translated_hash[:payload] = @post_payload
translated_hash[:faa_id]  = @faa_id
translated_hash

end # translate_ea_to_haven method end

def add_headers_to_finapp_in
#[finapp_id, tablename, person_id, id, type, tbd, key, value]

#sample properties data properties = {:content_type=>"application/octet-stream", :headers=>{"submitted_timestamp"=>2017-12-05 12:23:53 -0500, "correlation_id"=>"2916bf7f06ca4be1af85b790c7aba446", "family_id"=>"5a26d52d6012e43d6500000a", "assistance_application_id"=>"5a26d5816012e43d5f000000"}, :delivery_mode=>2, :priority=>0, :correlation_id=>"2916bf7f06ca4be1af85b790c7aba446", :timestamp=>2017-12-05 12:23:53 -0500, :app_id=>"enroll"}
#*********Note: please confirm naming conventions of keys
headers_mapping = { "submitted_timestamp" => "submittedtimestamp", "assistance_application_id" => "assistanceapplicationid", "correlation_id" => "correlationid", "family_id" => "familyid", "primary_applicant_id" => "primaryapplicantid", "havenic_id" => "havenicid", "ecase_id" => "ecaseid"}

@headers = @properties[:headers]	
finapp_in_headers = []
headers_mapping.each do |key, value|
	if @properties.keys.include?(key) || @headers.keys.include?(key)
	result = @properties[key] || @headers[key]
	finapp_in_headers << [@faa_id, "finapp_in", nil, nil, nil, nil, value, result]	
	finapp_in_headers << [@faa_id, "finapp_header", nil, nil, nil, nil, value, result]
	end #if end
end #do end
finapp_in_headers.delete_if {|arr| arr[-2] == "submittedtimestamp" && arr[1] == "finapp_in"}
return finapp_in_headers
end #add_headers_to_finapp_in  end


def log_ea_intake

payload = {

"action" => "INSERT", 
"Location" => "external_log", 
"xaid" => "value", 
"keyindex" => "finapp_id",
"keyvalue" => @faa_id,
"keytype" => "Log",
"keyresultid" => 1,  #This value is hardcoded to 1 but need to change in the future ref Tom. Ex: $icid in curam translator 
"status" => "Success",
"keytimestamp" => Time.now,
"queuename" => RABBIT_QUEUES[:ea_payload],
"requesttype" => "Sent",
"xmlpayload" => "#{@ea_xml}" 

}

application_in_res = RestClient.post('newsafehaven.dcmic.org/external_log_test.php', payload.to_s.gsub("=>", ":"), {content_type: :"application/json", accept: :"application/json"})
$EA_LOG.info("EA payload logged to external_log table with response status: #{application_in_res.code} \n payload: #{payload }")
application_in_res.body
end #log_ea_intake  end


end # module end

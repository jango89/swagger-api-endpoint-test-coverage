#!/usr/bin/env bash

#USAGE -> "validate-swagger-endpoint.sh 'collection/{collection_name}' 'stage-eu-alpha'"

# Reports directory being generated
mkdir -p reports
#Report name should start with `report`, since its used for attaching in emails(Jenkinsfile)
report_file_name="report-swagger-endpoints-missing.txt"
error_validation_file_path="$(pwd)/reports/$report_file_name"
#Clean up if files exists
rm -r -f "$error_validation_file_path"

# Check the first argument(filepath) to this function exists.
check_directory_exists () {
  #Check if schema directory exists and skip validation if not present.
    if [ "$(ls -1 "$1" | wc -l)" -eq 0 ]
      then
        echo "No collection found in path: $1"
        exit 0
    fi;
}

# Check the first argument(swagger endpoint) to this function exists.
check_first_argument_is_present() {
  if [[ $1 -lt 2 ]]
    then
      echo "ERROR -> Correct Usage: validate-swagger-endpoint.sh 'collection/{collection_name}' 'stage-eu-alpha'";
      exit 1
  fi

}

# Validate swagger endpoint from the swagger config
validate_swagger_endpoint_exists() {
  swagger_url="$1"

  swagger_endpoint_status="$(curl -s -o /dev/null -w '%{http_code}' "$swagger_url")"

  if [ "$swagger_endpoint_status" -ne 200 ]
    then
      echo "Error: Endpoint => '$swagger_url' is not accessible, since http status is: $swagger_endpoint_status.";
      exit 1
  fi
}

check_first_argument_is_present $#

current_working_directory="${PWD%/}/$1"

#Check if directory exists
check_directory_exists "$current_working_directory"

cd "$current_working_directory"

# Validating swagger endpoint by reading url from $2(environment name)
swagger_config_json_path="$(pwd)/swagger-config.json"
swagger_url=$(cat "$swagger_config_json_path" |  jq --raw-output '.'\"$2\"'."url"')
echo ""
echo "Validating all Swagger endpoints have at-least 1 API Test."
echo ""
echo "Invoking Swagger Url : $swagger_url"
echo ""
validate_swagger_endpoint_exists "$swagger_url" "$2"

# Skipped endpoints information displayed
skipped_end_points=$(cat "$swagger_config_json_path" | jq --raw-output '."skip-endpoints"[]')


#Read each api path
curl -s "$swagger_url" | jq --raw-output '.paths | keys[]' | while read line || [[ -n $line ]];
do

   # Loop through Skip Endpoints and validate api endpoints which are not skipped.
   echo "$skipped_end_points" | while read skipped_endpoint || [[ -n $skipped_endpoint ]];
   do
     if [[ "$line" =~ ^$skipped_endpoint.* ]];
       then
          echo "Skipping validation of Endpoint: $line"
       else
          #Replace '/getPaymentMetadata/{id}/{providerOrCollaboratorUuid}' -> '/getPaymentMetadata/*/*' for searching
          search_for_path_after_replacing=$(echo "$line" | sed --expression='s/{[^}]*}/*/g')

          #DEBUGGING ECHO
#          echo "Validating API Endpoint: '$search_for_path_after_replacing'"

          usages_found_for_api=$(grep -ri "$search_for_path_after_replacing" "." | wc -l)

          #Write to file if there is atleast one Endpoint missing API TESTS.
          if [ "$usages_found_for_api" -eq 0 ];
           then
              (echo "API Endpoint: ${search_for_path_after_replacing}, has no Tests found")  >> "$error_validation_file_path"
          fi
     fi
   done

done

#If file exists
if [ -f "$error_validation_file_path" ]
  then
    echo ""
    echo "Below API Endpoints are missing API Tests"
    echo "-------------------------------------------"
    cat "$error_validation_file_path"
    echo ""

    fail_on_error_for_environment=$(cat "$swagger_config_json_path" |  jq --raw-output '.'\"$2\"'."fail-build-on-errors"')

    if [ "$fail_on_error_for_environment" == "true" ] ;
      then
        echo "Failing build based on configuration."
        exit 1;
      else
        echo "Existing normally based on configuration."
        exit 0;
    fi
  else
    echo "All API Endpoints are having at-least 1 API Test."
    exit 0
fi

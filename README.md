# swagger-api-endpoint-test-coverage
Bash script to validate at-least one API TEST is written for each swagger endpoint

## How is it working?

The bash scripts accepts a directory in which "swagger-configuration.json" exists with API Endpoints test files also exists.

The json is downloaded from swagger url and later each endpoints are compared against the HTTP Files to make sure atleast ONE API Tests is present.

// Code generated by OpenAPI Generator (https://openapi-generator.tech); DO NOT EDIT.

/*
 * QC Write API
 *
 * No description provided (generated by Openapi Generator https://github.com/openapitools/openapi-generator)
 *
 * API version: v1
 */

package qcwriteapi




type TransactionSummaryResponse struct {

	Hash string `json:"hash,omitempty"`

	Metadata map[string]interface{} `json:"metadata,omitempty"`
}

// AssertTransactionSummaryResponseRequired checks if the required fields are not zero-ed
func AssertTransactionSummaryResponseRequired(obj TransactionSummaryResponse) error {
	return nil
}

// AssertTransactionSummaryResponseConstraints checks if the values respects the defined constraints
func AssertTransactionSummaryResponseConstraints(obj TransactionSummaryResponse) error {
	return nil
}
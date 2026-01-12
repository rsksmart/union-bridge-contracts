
# REQUEST PEGIN TXID (this should be completed at request-pegin.sh
export REQUEST_PEGIN_TXID=""


echo "================ STEP 1: REQUEST PEGIN ================"
bash "$SCRIPT_DIR/request-pegin.sh"

echo "================ STEP 2: REJECT PEGIN - BLOCK THE SLOT ================"
bash "$SCRIPT_DIR/reject-pegin.sh" -r "$REQUEST_PEGIN_TXID"

echo "================ REJECT PEGIN FLOW COMPLETE ================"

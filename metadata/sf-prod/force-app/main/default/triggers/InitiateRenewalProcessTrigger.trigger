trigger InitiateRenewalProcessTrigger on Initiate_Renewal_Process__e (after Insert) {
    InitiateRenewalProcessHandler.handleEventInsert(Trigger.new);
}
Config = {}

Config.AllowedJobs = {
    { job = "police", society = 'society_police', rank = 0 },
    { job = "ambulance", society = 'society_ambulance', rank = 0 },
    { job = "taxi", society = 'society_taxi', rank = 0 }
}

Config.Banks = {
    'v_corp_fleeca_display'
    }
    
Config.makeInvoicesCommand = 'bill'

Config.DiscordWebhook = {
    Invoices = "",
}

Config.UseBank = true -- default value true (uses the bank to pay the bill)

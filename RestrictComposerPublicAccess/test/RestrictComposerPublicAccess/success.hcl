module "tfplan-functions" {
  source = "../../../governance/third-generation/common-functions/tfplan-functions/tfplan-functions.sentinel"
}

mock "tfplan/v2" {
  module {
    source = "mock-tfplan-v2-success.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}

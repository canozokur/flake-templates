{
  description = "Personal flake templates collection";

  outputs = { self }: {
    templates = {
      services-flake = {
        path = ./services-flake;
        description = "Services-flake based template";
      };

      golang = {
        path = ./golang;
        description = "services-flake with golang app";
      };

      golang-private = {
        path = ./golang-private;
        description = "services-flake with golang app using private Go modules";
      };

      python = {
        path = ./python;
        description = "services-flake with python app";
      };

      terraform = {
        path = ./terraform;
        description = "nixpkgs-terraform based Terraform flake";
      };
    };

    defaultTemplate = self.templates.services-flake;
  };
}

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
    };

    defaultTemplate = self.templates.services-flake;
  };
}

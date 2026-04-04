{
  description = "Personal flake templates collection";

  outputs = { self }: {
    templates = {
      services-flake = {
        path = ./services-flake;
        description = "Services-flake based template";
      };
    };

    defaultTemplate = self.templates.services-flake;
  };
}

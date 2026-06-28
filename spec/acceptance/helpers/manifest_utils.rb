module Acceptance; end
module Acceptance::Helpers; end

module Acceptance::Helpers::ManifestUtils
  def print_test_config(hieradata, manifest)
    warn '>' * 80
    if hieradata.is_a?(Hash)
      warn "Hieradata:\n#{hieradata.to_yaml}"
    else
      warn "Hieradata:\n#{hieradata}"
    end
    warn '-' * 80
    warn "Manifest:\n#{manifest}"
    warn '<' * 80
  end

  def set_hiera_and_apply_on(host, hieradata, manifest, apply_opts = {}, verbose = true)
    print_test_config(hieradata, manifest) if verbose
    set_hieradata_on(host, hieradata)
    apply_manifest_on(host, manifest, apply_opts)
  end
end

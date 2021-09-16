module Acceptance
  module Helpers
    module ManifestUtils

      def print_test_config(hieradata, manifest)
        puts '>'*80
        if hieradata.is_a?(Hash)
          puts "Hieradata:\n#{hieradata.to_yaml}"
        else
          puts "Hieradata:\n#{hieradata}"
        end
        puts '-'*80
        puts "Manifest:\n#{manifest}"
        puts '<'*80
      end

      def set_hiera_and_apply_on(host, hieradata, manifest, apply_opts = {}, verbose = true )
        print_test_config(hieradata, manifest) if verbose
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, apply_opts)
      end

    end
  end
end

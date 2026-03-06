defmodule GA.Compliance.TaxonomyTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias GA.Compliance.Taxonomy
  alias GA.Compliance.Taxonomies

  describe "behaviour enforcement" do
    test "warns when callbacks are missing" do
      module_name = "GA.TestMissingTaxonomy#{System.unique_integer([:positive])}"

      warning =
        capture_io(:stderr, fn ->
          Code.compile_string("""
          defmodule #{module_name} do
            @behaviour GA.Compliance.Taxonomy
            def framework, do: "missing"
          end
          """)
        end)

      assert warning =~ "required by behaviour GA.Compliance.Taxonomy"
    end
  end

  describe "framework modules" do
    test "all modules expose taxonomy tree, flat actions, and semver version" do
      for module <- [Taxonomies.HIPAA, Taxonomies.SOC2, Taxonomies.PCIDSS, Taxonomies.GDPR, Taxonomies.ISO27001] do
        taxonomy = module.taxonomy()
        actions = module.actions()
        version = module.taxonomy_version()

        assert is_map(taxonomy)
        assert Enum.all?(taxonomy, fn {category, subcategories} ->
                 is_binary(category) and is_map(subcategories) and
                   Enum.all?(subcategories, fn {subcategory, sub_actions} ->
                     is_binary(subcategory) and is_list(sub_actions) and
                       Enum.all?(sub_actions, &is_binary/1)
                   end)
               end)

        assert is_list(actions)
        assert actions != []
        assert Enum.uniq(actions) == actions
        assert version =~ ~r/^\d+\.\d+\.\d+$/
      end
    end
  end

  describe "registry lookup and path resolution" do
    test "get/1 resolves known and unknown frameworks" do
      assert {:ok, Taxonomies.HIPAA} = Taxonomy.get("hipaa")
      assert {:ok, Taxonomies.ISO27001} = Taxonomy.get("iso_27001")
      assert {:error, :unknown_framework} = Taxonomy.get("unknown")
    end

    test "list_frameworks/0 returns sorted identifiers" do
      assert Taxonomy.list_frameworks() == ["gdpr", "hipaa", "iso_27001", "pci_dss", "soc2"]
    end

    test "resolve_path/2 supports exact and wildcard paths" do
      assert {:ok, ["phi_read"]} =
               Taxonomy.resolve_path(Taxonomies.HIPAA, "access.phi.phi_read")

      assert {:ok, actions} = Taxonomy.resolve_path(Taxonomies.HIPAA, "access.phi.*")
      assert actions == ["phi_read", "phi_write", "phi_delete"]

      assert {:ok, actions} = Taxonomy.resolve_path(Taxonomies.HIPAA, "access.*")
      assert Enum.sort(actions) == Enum.sort(["phi_read", "phi_write", "phi_delete", "login", "logout", "session_timeout"])

      assert {:error, :invalid_path} =
               Taxonomy.resolve_path(Taxonomies.HIPAA, "access.nonexistent.*")
    end
  end
end

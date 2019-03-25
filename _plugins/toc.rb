module Jekyll
  class TableOfContents < Jekyll::Generator
    PageNotFoundError = Class.new(::RuntimeError)

    def generate(site)
      index_page = page_by_name("index", site)
      generate_toc_pages([], index_page, site)

      order = walk(index_page, site)
      site.config["toc_pages"] = order
    end

    def walk(page, site)
      if page.data["toc"] and page.data["toc_pages"]
        [ page ] + page.data["toc_pages"].map { |x| walk(x, site) }
                   .inject { |sum, x| sum + x }
      else
        [ page ]
      end
    end

    def generate_toc_pages(prefix, page, site)
      page.data["toc_index"] = prefix
      page.data["toc_depth"] = prefix.count
      if page.data["toc"]
        prev_page = nil
        page.data["toc_pages"] = page.data["toc"].each_with_index.map do |toc_page_name, i|
          sub_page = page_by_name(toc_item_name(page.path, toc_page_name), site)
          sub_page.data["up_page"] = page
          if prev_page
            sub_page.data["prev_page"] = prev_page
            prev_page.data["next_page"] = sub_page
          end
          prev_page = sub_page
          generate_toc_pages(prefix + [i + 1], sub_page, site)
          sub_page
        end
      end
    end

    def toc_item_name(parent_path, toc_name)
      parent_path = path_without_extension(parent_path)
      if parent_path == "index"
        toc_name
      else
        "#{parent_path}/#{toc_name}"
      end
    end

    def page_by_name(name, site)
      result = site.pages.find do |page|
        path_without_extension(page.path) == name
      end
      raise PageNotFoundError if result == nil
      result
    end

    def path_without_extension(path)
      path.split(".")[0...-1].join(".")
    end
  end
end

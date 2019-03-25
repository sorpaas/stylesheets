module Jekyll
  module Filters
    def date_to_jbo(date)
      d = time(date)

      "li #{d.year} pi'e #{d.month} pi'e #{d.day}"
    end

    private
    def number_to_jbo(num)
      num.to_s.
        gsub(/0/, 'no').
        gsub(/1/, 'pa').
        gsub(/2/, 're').
        gsub(/3/, 'ci').
        gsub(/4/, 'vo').
        gsub(/5/, 'mu').
        gsub(/6/, 'xa').
        gsub(/7/, 'ze').
        gsub(/8/, 'bi').
        gsub(/9/, 'so')
    end
  end
end

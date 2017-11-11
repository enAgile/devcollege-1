class Movie < Media
  attr_accessor *%i(name summary rental_price price copyrights artist)
  class << self
    def top10(genre)
      movies_top10(genre)
    end
  end
end
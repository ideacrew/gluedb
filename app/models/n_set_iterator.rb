class NSetIterator
  include Enumerable

  def initialize(size, items)
    @array = items
    @n = size
  end

  def each
    total_size = @array.length
    return if total_size < @n
    @array.each_index do |i|
      break if i > (total_size - @n + 1)
      head = @array.first(i)
      items = @array[i..i+(@n-1)]
      rest = @array[(i+@n)..-1]
      yield [head, items, rest]
    end
  end
end
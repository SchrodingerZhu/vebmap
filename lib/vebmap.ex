defmodule Vebmap.KeyError do
  defexception [:message]
  def exception(key) do
    %Vebmap.KeyError{message: "this vebmap doesn\'t have the key #{key}"}
  end
end
defmodule Vebmap do
  @behaviour Access
  @moduledoc """
  Documentation for Vebmap.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Vebmap.hello()
      :world

  """
  defstruct veb: Veb.new(2147483647), map: Map.new
  
  def new(limit, mode \\ :by_max) do
    %Vebmap{veb: Veb.new(limit, mode), map: Map.new}
  end
  def delete(vebmap, key) do
    %Vebmap{veb: vebmap.veb |> Veb.delete(key), map: vebmap.map |> Map.delete(key)}
  end

  def drop(vebmap, []), do: vebmap
  def drop(vebmap, [head | tail]), do: drop(delete(vebmap, head), tail)

  def equal?(vebmap1, vebmap2), do: Map.equal?(vebmap1.map, vebmap2.map)

  def fetch!(vebmap, key) do
    case fetch(vebmap, key) do
      :error -> raise(Vebmap.KeyError, key)
      res -> res
    end
  end

  def fetch(vebmap, key) do
    Map.fetch(key)
  end

  def get(vebmap, key, default \\ nil) do
    Map.get(vebmap, key, default)
  end

  def get_and_update!(vebmap, key, fun) do
    value = fetch!(map, key)
    case fun.(value) do
      {get, update} ->
        {get, %Vebmap{vebmap | map: Map.put(vebmap.map, key, update)}}
      :pop ->
        {value, delete(vebmap, key)}
      other ->
        {get, put(vebmap, key, update)}
    end
  end


  def get_and_update(vebmap, key, fun) do
    current = get(vebmap, key)
    case fun.(current) do
      {get, update} ->
        {get, %Vebmap{vebmap | map: Map.put(vebmap.map, key, update)}}
      :pop ->
        {get, delete(vebmap, key)}
      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end

    def get_lazy(vebmap, key, fun) when is_function(fun, 0) do
      case fetch(vebmap, key) do
        :error -> fun.()
        value -> value
      end
    end

    def has_key?(vebmap, key) do
      Map.has_key?(vebmap.map, key)
    end

    def keys(vebmap) do
      Map.keys(vebmap.map)
    end

    def merge(vebmap1, vebmap2) do
      map = Map.merge(vebmap1.map, vebmap2.map)
      the_keys = keys(vebmap2)
      %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
    end

    defp put_keys(veb, []), do: veb
    defp put_keys(veb, [head | tail]), do: put_keys(Veb.insert(veb, head), tail)

    def merge(vebmap1, vebmap2, fun) do
      map = Map.merge(vebmap1.map, vebmap2.map, fun)
      the_keys = keys(vebmap2)
      %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
    end

    def new(enumerable), do: nil

    def put(vebmap, key, value) do
      %Vebmap{veb: Veb.insert(vebmap.veb, key), map: Map.put(vebmap.map, key, value)}
    end

  end
  

end

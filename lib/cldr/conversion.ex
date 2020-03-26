defmodule Cldr.Unit.Conversion do
  @moduledoc """
  Unit conversion functions for the units defined
  in `Cldr`.

  """

  alias Cldr.Unit
  import Unit, only: [incompatible_units_error: 2]
  import Cldr.Unit.Conversions, only: [conversion_factor: 1]

  defmodule Options do
    defstruct [usage: nil, scope: nil, locale: nil, backend: nil, alt: nil]
  end

  @doc """
  Convert one unit into another unit of the same
  unit type (length, volume, mass, ...)

  ## Arguments

  * `unit` is any unit returned by `Cldr.Unit.new/2`

  * `to_unit` is any unit name returned by `Cldr.Unit.units/0`

  ## Returns

  * a `Unit.t` of the unit type `to_unit` or

  * `{:error, {exception, message}}`

  ## Examples

      iex> Cldr.Unit.convert Cldr.Unit.new!(:celsius, 0), :fahrenheit
      #Unit<:fahrenheit, 32>

      iex> Cldr.Unit.convert Cldr.Unit.new!(:fahrenheit, 32), :celsius
      #Unit<:celsius, 0>

      iex> Cldr.Unit.convert Cldr.Unit.new!(:mile, 1), :foot
      #Unit<:foot, 5280>

      iex> Cldr.Unit.convert Cldr.Unit.new!(:mile, 1), :gallon
      {:error, {Cldr.Unit.IncompatibleUnitsError,
        "Operations can only be performed between units of the same type. Received :mile and :gallon"}}

  """
  @spec convert(Unit.t(), Unit.unit()) :: Unit.t() | {:error, {module(), String.t()}}

  def convert(%Unit{unit: from_unit, value: _value} = unit, from_unit) do
    unit
  end

  def convert(%Unit{unit: from_unit, value: value}, to_unit) do
    with {:ok, to_unit} <- Unit.validate_unit(to_unit),
         true <- Unit.compatible?(from_unit, to_unit),
         {:ok, from_conversion} <- get_conversions(from_unit),
         {:ok, to_conversion} <- get_conversions(to_unit),
         {:ok, converted} <- convert(value, from_conversion, to_conversion) do
      Unit.new(to_unit, converted)
    else
      {:error, _} = error -> error
      false -> {:error, incompatible_units_error(from_unit, to_unit)}
    end
  end

  defp get_conversions(unit) do
    if factors = conversion_factor(unit) do
      {:ok, factors}
    else
      {:error,  {Cldr.Unit.UnitNotConvertibleError,
        "No conversion is possible for #{inspect unit}"}}
    end
  end

  defp convert(value, from, to) when is_number(value) do
    use Ratio

    %{factor: from_factor, offset: from_offset} = from
    %{factor: to_factor, offset: to_offset} = to

    base = (value * from_factor) + from_offset
    converted = ((base - to_offset) / to_factor) |> Ratio.to_float

    truncated = trunc(converted)

    if converted == truncated do
      {:ok, truncated}
    else
      {:ok, converted}
    end
  end

  defp convert(%Decimal{} = value, from, to) do
    use Ratio

    %{factor: from_factor, offset: from_offset} = from
    %{factor: to_factor, offset: to_offset} = to

    base =
      Ratio.new(value)
      |> Ratio.mult(Ratio.new(from_factor))
      |> Ratio.add(Ratio.new(from_offset))

    converted =
      base
      |> Ratio.sub(Ratio.new(to_offset))
      |> Ratio.div(Ratio.new(to_factor))
      |> to_decimal

    {:ok, converted}
  end

  defp convert(_value, from, to) do
    {:error,
     {Cldr.Unit.UnitNotConvertibleError,
      "No conversion is possible between #{inspect(to)} and #{inspect(from)}"}}
  end

  @doc """
  Convert one unit into another unit of the same
  unit type (length, volume, mass, ...) and raises
  on a unit type mismatch

  ## Arguments

  * `unit` is any unit returned by `Cldr.Unit.new/2`

  * `to_unit` is any unit name returned by `Cldr.Unit.units/0`

  ## Returns

  * a `Unit.t` of the unit type `to_unit` or

  * raises an exception

  ## Examples

      iex> Cldr.Unit.Conversion.convert! Cldr.Unit.new!(:celsius, 0), :fahrenheit
      #Unit<:fahrenheit, 32>

      iex> Cldr.Unit.Conversion.convert! Cldr.Unit.new!(:fahrenheit, 32), :celsius
      #Unit<:celsius, 0>

      Cldr.Unit.Conversion.convert Cldr.Unit.new!(:mile, 1), :gallon
      ** (Cldr.Unit.IncompatibleUnitsError) Operations can only be performed between units of the same type. Received :mile and :gallon

  """
  @spec convert!(Unit.t(), Unit.unit()) :: Unit.t() | no_return()

  def convert!(%Unit{} = unit, to_unit) do
    case convert(unit, to_unit) do
      {:error, {exception, reason}} -> raise exception, reason
      unit -> unit
    end
  end

end

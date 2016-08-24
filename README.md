# Efflux

A simple driver for [InfluxDB](https://influxdata.com). Currently it only supports querying InfluxDB, hence the name Efflux.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `efflux` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:efflux, "~> 0.1.0"}]
    end
    ```

  2. Ensure `efflux` is started before your application:

    ```elixir
    def application do
      [applications: [:efflux]]
    end
    ```

## Usage

    ```elixir
    Enum.into(Efflux.execute("show series", host: "localhost", database: "stuff"), [])
    ```


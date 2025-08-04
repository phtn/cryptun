defmodule Cryptun.ErrorHTML do
  use Phoenix.Component

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render(template, _assigns) do
  #   Phoenix.Controller.status_message_from_template(template)
  # end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
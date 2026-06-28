defmodule GratefulSetCrewWeb.PageController do
  use GratefulSetCrewWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

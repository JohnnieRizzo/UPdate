alias GratefulSetCrew.{Accounts, Repo}
alias GratefulSetCrew.Accounts.User
import Ecto.Changeset

insert_admin = fn email, password ->
  %User{}
  |> User.registration_changeset(%{email: email, role: "client"})
  |> User.password_changeset(%{password: password})
  |> put_change(:role, "admin")
  |> put_change(:confirmed_at, DateTime.truncate(DateTime.utc_now(), :second))
  |> Repo.insert!()
end

{:ok, _} = Accounts.register_user(%{email: "thesicbrand@gmail.com", role: "crew"})

insert_admin.("dollainthemix71@gmail.com", "AdminPass456!")
insert_admin.("gratefulsetcrew@gmail.com", "CompanySecurePwd!")

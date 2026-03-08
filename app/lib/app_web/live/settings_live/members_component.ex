defmodule GAWeb.SettingsLive.MembersComponent do
  @moduledoc false

  use GAWeb, :live_component

  require Logger

  alias GA.Accounts

  @allowed_roles ~w(admin member)

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="members-settings" class="space-y-6">
      <%!-- Members table --%>
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Email</th>
              <th>Role</th>
              <th>Joined</th>
              <th :if={@role == :owner} class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={member <- @members} id={"member-#{member.id}"}>
              <td class="font-mono text-sm">{member.user.email}</td>
              <td>
                <%= if @role == :owner and member.role != :owner do %>
                  <select
                    class="select select-bordered select-xs"
                    phx-change="change_role"
                    phx-target={@myself}
                    name="role"
                    data-member-id={member.id}
                    phx-value-member-id={member.id}
                  >
                    <option value="admin" selected={member.role == :admin}>Admin</option>
                    <option value="member" selected={member.role == :member}>Member</option>
                  </select>
                <% else %>
                  <.role_badge role={member.role} />
                <% end %>
              </td>
              <td class="text-sm text-base-content/50">
                {Calendar.strftime(member.inserted_at, "%b %d, %Y")}
              </td>
              <td :if={@role == :owner} class="text-right">
                <button
                  :if={member.role != :owner}
                  class="btn btn-ghost btn-xs text-error"
                  phx-click="remove_member"
                  phx-target={@myself}
                  phx-value-member-id={member.id}
                  data-confirm="Are you sure you want to remove this member?"
                >
                  Remove
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- Invite placeholder --%>
      <div class="border border-dashed border-base-300 rounded-lg p-4 flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-base-content/70">Invite Members</p>
          <p class="text-xs text-base-content/40">Send invitations to join this account</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge badge-ghost badge-sm">Coming soon</span>
          <button class="btn btn-sm btn-disabled" disabled>Invite</button>
        </div>
      </div>
    </div>
    """
  end

  defp role_badge(assigns) do
    color =
      case assigns.role do
        :owner -> "badge-primary"
        :admin -> "badge-secondary"
        :member -> "badge-ghost"
        _ -> "badge-ghost"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"badge badge-sm #{@color}"}>{@role}</span>
    """
  end

  @impl true
  def handle_event("change_role", %{"role" => role, "member-id" => member_id}, socket)
      when socket.assigns.role == :owner do
    if role in @allowed_roles do
      account_user = Accounts.get_account_user!(member_id, socket.assigns.account)

      case Accounts.update_account_user_role(account_user, String.to_existing_atom(role)) do
        {:ok, _} ->
          send(self(), :members_updated)
          {:noreply, put_flash(socket, :info, "Role updated successfully.")}

        {:error, reason} ->
          Logger.error("Failed to update role",
            account_id: socket.assigns.account.id,
            member_id: member_id,
            error: inspect(reason)
          )

          {:noreply, put_flash(socket, :error, "Failed to update role.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid role.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"member-id" => member_id}, socket)
      when socket.assigns.role == :owner do
    account_user = Accounts.get_account_user!(member_id, socket.assigns.account)

    case Accounts.remove_user_from_account(account_user.account, account_user.user) do
      {:ok, _} ->
        send(self(), :members_updated)
        {:noreply, put_flash(socket, :info, "Member removed successfully.")}

      {:error, reason} ->
        Logger.error("Failed to remove member",
          account_id: socket.assigns.account.id,
          member_id: member_id,
          error: inspect(reason)
        )

        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end

  # Catch-all for unauthorized role changes/removals
  def handle_event(event, _params, socket)
      when event in ["change_role", "remove_member"] do
    {:noreply, put_flash(socket, :error, "You are not authorized to perform this action.")}
  end
end

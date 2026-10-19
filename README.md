# Network Share Mapper v7 (NSM) — Instructions



Network Folder Mapper v7 is a PowerShell/WinForms application for saving users and UNC network locations, connecting to shares, and managing Windows network shortcuts.

> **Note:** This folder contains `users.csv` with fake test data only. Do not use it as a real user database.

## Files

Keep these files in the same folder:

- `NetworkFolderMapper_v7.ps1` — the PowerShell application.
- `users.csv` — saved users, passwords, and network locations.

## Requirements

- Windows with Windows PowerShell 5.1.
- Access to the UNC network locations you want to use, for example `\\192.168.1.150\ShareName`.
- Permission to run PowerShell scripts in your environment.

## How to run

1. Confirm that the `.ps1` file and `users.csv` are in the same folder.
2. Right-click `NetworkFolderMapper_v7.ps1` and select **Run with PowerShell**.
3. If script execution is blocked, open PowerShell in that folder and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\NetworkFolderMapper_v7.ps1
   ```

The `-Scope Process` setting applies only to the current PowerShell process and does not permanently change the system policy.

## Tabs and features

### Connect

- The saved network-location list shows the saved display name for each item.
- Select one or more items, then select **Apply** to connect and create Windows Network Location shortcuts.
- **Remove** disconnects the share and removes the corresponding network shortcut.
- **Select all** and **Select none** select or clear all items.
- **Refresh** reloads the data from `users.csv`.
- The status list at the bottom shows `OK` or `ERROR` messages.

### Mutual shares

This tab is used to add or remove a shared network location, including a share intended for access by everyone:

1. Enter a UNC path in **Share location**, for example `\\192.168.1.150\Common`.
2. In **Connect as**, select a saved user or `(current Windows login)`.
3. Select **Add** to connect and save the share in `users.csv`.
4. Select **Remove** to disconnect, remove the shortcut, and delete the saved row from `users.csv`.

**Currently used by** shows the saved display name and username for the current path, if a matching row exists.

### Add user

- Enter **Username**, **Password**, **Share path**, and **Display name**.
- **Save** adds the user to `users.csv`.
- **Delete** removes the selected user from `users.csv`.
- The path must be a valid UNC path in the form `\\server\share`.

### Edit user

- Select a saved user.
- Edit the username, password, share path, or display name.
- **Save changes** saves the edits.
- **Refresh** reloads the lists and data from the CSV file.

## `users.csv` file format

The CSV must have these columns, in this order:

| Column | Description | Example |
|---|---|---|
| `Username` | Username used for network authentication. | `TestUser1` |
| `Password` | Password used for network authentication. | `Test1234!` |
| `SharePath` | UNC path to the share. | `\\192.168.1.150\TestUser1` |
| `DisplayName` | Name shown in the application. | `Test User One Private` |

Example row:

```csv
"TestUser1","Test1234!","\\192.168.1.150\TestUser1","Test User One Private"
```

The application reads and writes the CSV in UTF-8 format. Values are properly quoted, which allows commas and special characters in fields to be read safely.

## Important Windows notes

Windows generally maintains one active login or credential session per server name. If you need to use different credentials for shares on the same server, first disconnect existing sessions or use a different server name or IP address where appropriate.

## Troubleshooting

- **The script does not start:** run it from PowerShell after `Set-ExecutionPolicy -Scope Process Bypass`, or check your organization's policies.
- **`users.csv` is not found:** confirm that it is in the same folder as `NSM.ps1`.
- **The CSV cannot be loaded:** check the header `Username,Password,SharePath,DisplayName`, UTF-8 encoding, and that every row is correctly formatted.
- **`Invalid UNC path`:** use the form `\\server\share`, not a local path such as `C:\Folder`.
- **Authentication failed / Cannot access:** check network availability, username, password, share permissions, and existing Windows sessions to the server.
- **The shortcut is not visible:** check `AppData\Roaming\Microsoft\Windows\Network Shortcuts` and try **Apply** again.
- **Changes are not visible in the lists:** select **Refresh**.

## Plaintext password warning

Passwords are stored as plaintext in `users.csv`. Restrict permissions on the file and folder, do not send the file by email or store it in a public repository, and use only test data in development environments.

All values in the included `users.csv` are **fake test data** and are not real credentials.

**Credit:** Misel Blatancic 2026

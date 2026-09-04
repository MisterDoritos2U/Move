Function Start-MarshallingEvents ($Event) {

    Switch ($Event) {

        SyncTreeView {

            Sync-TreeView

        }
        UpdatePEListBox {         

            # Clear old listbox items.
            $SyncHash.ListBoxPrismElement.Items.Clear() | Out-Null
    
            # Add items to listbox from updated list.
            If ($SyncHashData.UpdatedList) {
                Add-ListBoxItems "ListBoxPrismElement" $SyncHashData.UpdatedList -TreeViewItems @($SyncHash.TreeView.Items | ForEach-Object { $_.Tag })
            }

        }

    }

}
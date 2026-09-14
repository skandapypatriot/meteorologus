import SwiftUI

/// Mirrors `device_selector.dart`.
/// Shows a single device's MAC as a chip, or a dropdown menu when several exist.
struct DeviceSelectorView: View {
    let devices: [OwnedDevice]
    let selectedDevice: OwnedDevice?
    let onSelected: (OwnedDevice) -> Void
    let onClaimNew: () -> Void
    let textColor: Color

    var body: some View {
        if devices.isEmpty {
            EmptyView()
        } else if devices.count == 1 {
            chip(mac: selectedDevice?.mac ?? devices[0].mac, showMenu: false)
        } else if let selected = selectedDevice {
            Menu {
                ForEach(devices) { device in
                    Button {
                        onSelected(device)
                    } label: {
                        Text(device.formattedMac).font(.system(.caption, design: .monospaced))
                    }
                }
                Divider()
                Button(action: onClaimNew) {
                    Label("Claim new node", systemImage: "plus")
                }
            } label: {
                chip(mac: selected.formattedMac, showMenu: true)
            }
        }
    }

    private func chip(mac: String, showMenu: Bool) -> some View {
        HStack(spacing: 4) {
            Text(mac)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .lineLimit(1)
                .foregroundColor(textColor)
            if showMenu {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.2))
        .glassEffect(.regular.interactive(), in: Capsule())
        .clipShape(Capsule())
    }
}
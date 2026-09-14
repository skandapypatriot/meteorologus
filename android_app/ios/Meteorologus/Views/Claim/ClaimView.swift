import SwiftUI

/// Mirrors `claim_dialog.dart`: a modal sheet for claiming a weather node by MAC.
struct ClaimView: View {
    @ObservedObject var weather: WeatherViewModel
    @ObservedObject var auth: AuthViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var macText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSuccess = false
    @State private var showScanner = false

    let claimService = ClaimService()

    private var brandBlue: Color { Color(red: 0.23, green: 0.51, blue: 0.96) }

    var body: some View {
        let brandBlue = Color(red: 0.23, green: 0.51, blue: 0.96)

        ZStack {
            // Gradient background matching dashboard
            LinearGradient(
                colors: [Color(red: 0.078, green: 0.071, blue: 0.302),
                         Color(red: 0.247, green: 0.239, blue: 0.545)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onTapGesture { hideKeyboard() }

            VStack {
                Spacer()
                GlassCard(
                    padding: EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20),
                    backgroundColor: Color(red: 0.078, green: 0.071, blue: 0.302).opacity(0.94),
                    borderColor: Color.white.opacity(0.16)
                ) {
                    if isSuccess {
                        successContent
                    } else {
                        formContent(brandBlue: brandBlue)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Form

    private func formContent(brandBlue: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Claim Weather Node")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Text("Enter the 12-character MAC address shown on your node display or scan its QR code.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.71))
                .padding(.top, 12)

            // MAC text field
            HStack {
                TextField("e.g. 7CDF8B62AC88", text: $macText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .overlay(alignment: .trailing) {
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Color(red: 0.37, green: 0.65, blue: 0.98))
                        }
                    }
            }
            .padding(14)
            .background(Color.black.opacity(0.32))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 16)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.44, blue: 0.52))
                    .padding(.top, 8)
            }

            // Claim button
            Button {
                Task { await handleClaim() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Claim Device")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(brandBlue)
            .disabled(isLoading)
            .padding(.top, 18)

            Button {
                showScanner = true
            } label: {
                Label("Scan with Camera", systemImage: "camera.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
            .tint(brandBlue)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                macText = code
                errorMessage = nil
            }
        }
    }

    // MARK: - Success

    private var successContent: some View {
        VStack(spacing: 0) {
            Text("\u{2705}")
                .font(.system(size: 48))
            Text("Device Claimed!")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .padding(.top, 12)
            Text("The node will pick up its key when it connects and start syncing automatically.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.71))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Button {
                dismiss()
                Task { await weather.refresh() }
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(brandBlue)
            .padding(.top, 20)
        }
    }

    // MARK: - Claim action

    @MainActor
    private func handleClaim() async {
        let mac = ClaimService.normalizeMac(macText)
        guard ClaimService.isValidMac(mac) else {
            errorMessage = "Invalid MAC. Please enter 12 hexadecimal characters."
            return
        }
        guard let uid = auth.userID, let token = auth.session?.idToken else {
            errorMessage = "You must be signed in to claim a device."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let alreadyClaimed = try await claimService.isDeviceClaimed(mac: mac, authToken: token)
            if alreadyClaimed {
                errorMessage = "This device is already claimed by an account."
                isLoading = false
                return
            }
            try await claimService.claimDevice(uid: uid, mac: mac, authToken: token)
            isLoading = false
            isSuccess = true
        } catch {
            errorMessage = "Claim failed: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
import SwiftUI

struct MainScreen: View {
    @ObservedObject var output: MainScreenPresenter
    
    @State var sendMessageShowed = false
    @State var message = ""
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(alignment: .leading, spacing: 16) {
                    if output.state.signalingConnected {
                        Text("Signaling status: Connected")
                            .foregroundColor(.green)
                    } else {
                        Text("Signaling status: Not connected")
                            .foregroundColor(.red)
                    }
                    
                    Text("Local SDP: \(output.state.hasLocalSessionDescription ? "✅" : "❌")")
                    
                    Text("Local Candidates: \(output.state.localCandidates)")
                    
                    Text("Remote SDP: \(output.state.hasRemoteSessionDescription ? "✅" : "❌")")
                    
                    Text("Remote Candidates: \(output.state.remoteCandidates)")
                    
                    Text("WebRTC Status: \(output.state.webRTCStatus)")
                }
                
                Spacer()
                
                VStack {
                    HStack {
                        Button(output.state.audioIsMuted ? "Unmute" : "Mute") {
                            output.dispatch(.mute)
                        }
                        .padding()
                        .background(Color.white)
                        .disabled(true)
                        
                        Spacer()
                        Button(output.state.speakerIsMuted ? "Unmute speaker" : "Mute speaker") {
                            output.dispatch(.muteSpeaker)
                        }
                        
                        .padding()
                        .background(Color.white)
                        .disabled(true)
                    }
                    
                    HStack {
                        Button("Send Message") {
                            sendMessageShowed = true
                        }
                        .padding()
                        .background(Color.white)
                        .disabled(true)
                        
                        Spacer()
                        
                        Button("Open video") {
                            output.dispatch(.openVideo)
                        }
                        .padding()
                        .background(Color.white)
                    }
                }
                
                VStack(spacing: 16.0) {
                    
                    Button("Send offer") {
                        output.dispatch(.sendOffer)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color.white)
                    .background(Color.black)

                    Button("Send answer") {
                        output.dispatch(.sendAnswer)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color.white)
                    .background(Color.black)
                }
            }
            .padding()
            .navigationBarTitle("WebRTC SocketIO")
        }
        .textFieldAlert(message: $message, isPresented: $sendMessageShowed)
        .alert(
            message: output.state.error?.localizedDescription ?? output.state.message,
            buttonText: "Ok",
            isPresented: .constant(output.state.showError || output.state.showMessage),
            completion: {
                if output.state.showError {
                    output.dispatch(.hideError)
                }
                if output.state.showMessage {
                    output.dispatch(.hideMessage)
                }
            }
        )
    }
}

extension View {
    func alert(
        message: String,
        buttonText: String,
        isPresented: Binding<Bool>,
        completion: @escaping (() -> Void) = {}
    ) -> some View {
        if #available(iOS 15.0, *) {
            return alert(
                message,
                isPresented: isPresented,
                actions: {
                    Button(buttonText, role: .cancel, action: completion)
                }
            )
        } else {
            return alert(isPresented: isPresented) {
                Alert(
                    title: Text(message),
                    dismissButton: .cancel(
                        Text(buttonText),
                        action: completion
                    )
                )
            }
        }
    }
}

extension View {
    func textFieldAlert(
        message: Binding<String>,
        isPresented: Binding<Bool>,
        completion: @escaping (() -> Void) = {}
    ) -> some View {
        if #available(iOS 15.0, *) {
            return alert(
                Text("HI!"),
                isPresented: isPresented,
                actions: {
                    TextField("Enter your message", text: message)
                    Button("Send", role: .cancel, action: completion)
                }
            )
        } else {
            return alert(isPresented: isPresented) {
                Alert(title: Text("Ой, обнови свой телефон"))
            }
        }
    }
}


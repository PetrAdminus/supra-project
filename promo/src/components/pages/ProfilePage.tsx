import { User, Mail, Wallet, Trophy, Settings, Shield } from "lucide-react";
import { Card } from "../ui/card";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Avatar, AvatarFallback } from "../ui/avatar";

export function ProfilePage() {
  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10 max-w-6xl">
        <div className="mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-purple-400 to-cyan-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Profile
          </h2>
          <p className="text-lg text-gray-400">Manage your account settings and preferences</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Profile Info */}
          <div className="lg:col-span-1 space-y-6">
            {/* Profile Card */}
            <Card className="glass-strong p-6 rounded-2xl border-purple-500/30 glow-purple">
              <div className="flex flex-col items-center text-center">
                <Avatar className="w-24 h-24 mb-4 bg-gradient-to-br from-cyan-500 to-purple-600">
                  <AvatarFallback className="text-2xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                    SL
                  </AvatarFallback>
                </Avatar>
                <h3 className="text-2xl text-white mb-1" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                  Supra User
                </h3>
                <code className="text-sm text-cyan-400 bg-cyan-500/10 px-3 py-1 rounded mb-4">
                  0x1a2b...3c4d
                </code>
                <Button variant="outline" className="glass text-white border-cyan-400/50 hover:border-cyan-400 w-full rounded-xl">
                  <Settings className="w-4 h-4 mr-2" />
                  Edit Profile
                </Button>
              </div>
            </Card>

            {/* Stats Card */}
            <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20">
              <h4 className="text-lg text-white mb-4" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Quick Stats
              </h4>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Trophy className="w-4 h-4 text-purple-400" />
                    <span className="text-sm text-gray-400">Total Wins</span>
                  </div>
                  <span className="text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>1</span>
                </div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Wallet className="w-4 h-4 text-cyan-400" />
                    <span className="text-sm text-gray-400">Total Tickets</span>
                  </div>
                  <span className="text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>5</span>
                </div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Shield className="w-4 h-4 text-pink-400" />
                    <span className="text-sm text-gray-400">Member Since</span>
                  </div>
                  <span className="text-pink-400">Sep 2025</span>
                </div>
              </div>
            </Card>
          </div>

          {/* Right Column - Settings */}
          <div className="lg:col-span-2 space-y-6">
            {/* Wallet Information */}
            <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
              <h3 className="text-2xl text-white mb-6" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Wallet Information
              </h3>
              <div className="space-y-4">
                <div>
                  <Label className="text-gray-400 mb-2 block">Wallet Address</Label>
                  <div className="flex gap-3">
                    <Input
                      value="0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r"
                      readOnly
                      className="glass text-gray-300 border-gray-700"
                    />
                    <Button className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white rounded-xl">
                      Copy
                    </Button>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-gray-400 mb-2 block">Balance</Label>
                    <div className="glass p-4 rounded-xl border-purple-500/30">
                      <p className="text-2xl text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
                        2,450 SUPRA
                      </p>
                    </div>
                  </div>
                  <div>
                    <Label className="text-gray-400 mb-2 block">Network</Label>
                    <div className="glass p-4 rounded-xl border-cyan-500/30">
                      <p className="text-lg text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                        Supra Network
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </Card>

            {/* Notification Preferences */}
            <Card className="glass-strong p-8 rounded-2xl border-purple-500/20">
              <h3 className="text-2xl text-white mb-6" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Notification Preferences
              </h3>
              <div className="space-y-4">
                <div className="flex items-center justify-between glass p-4 rounded-xl">
                  <div>
                    <p className="text-white">Draw Results</p>
                    <p className="text-sm text-gray-400">Get notified when draw results are announced</p>
                  </div>
                  <input type="checkbox" defaultChecked className="w-5 h-5" />
                </div>
                <div className="flex items-center justify-between glass p-4 rounded-xl">
                  <div>
                    <p className="text-white">Winning Alerts</p>
                    <p className="text-sm text-gray-400">Instant notification when you win</p>
                  </div>
                  <input type="checkbox" defaultChecked className="w-5 h-5" />
                </div>
                <div className="flex items-center justify-between glass p-4 rounded-xl">
                  <div>
                    <p className="text-white">New Draws</p>
                    <p className="text-sm text-gray-400">Alert when new draws are available</p>
                  </div>
                  <input type="checkbox" className="w-5 h-5" />
                </div>
              </div>
            </Card>

            {/* Security */}
            <Card className="glass-strong p-8 rounded-2xl border-pink-500/20">
              <h3 className="text-2xl text-white mb-6" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Security
              </h3>
              <div className="space-y-4">
                <Button variant="outline" className="w-full glass text-white border-cyan-400/50 hover:border-cyan-400 rounded-xl justify-start">
                  <Shield className="w-4 h-4 mr-2" />
                  Enable Two-Factor Authentication
                </Button>
                <Button variant="outline" className="w-full glass text-white border-purple-400/50 hover:border-purple-400 rounded-xl justify-start">
                  <Wallet className="w-4 h-4 mr-2" />
                  Disconnect Wallet
                </Button>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}

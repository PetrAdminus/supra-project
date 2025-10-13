import { Mail, MessageCircle, HelpCircle, Book, Send } from "lucide-react";
import { Card } from "../ui/card";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Textarea } from "../ui/textarea";
import { Label } from "../ui/label";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "../ui/accordion";

export function SupportPage() {
  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10 max-w-6xl">
        {/* Header */}
        <div className="text-center mb-16">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-purple-400 to-cyan-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Support Center
          </h2>
          <p className="text-lg text-gray-400 max-w-3xl mx-auto">
            We&apos;re here to help you with any questions or issues
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-12">
          {/* Contact Options */}
          <div className="lg:col-span-1 space-y-6">
            <Card className="glass-strong p-6 rounded-2xl border-cyan-500/30 glow-cyan">
              <h3 className="text-2xl text-white mb-6" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Get in Touch
              </h3>

              <div className="space-y-4">
                <div className="glass p-4 rounded-xl hover:bg-white/10 transition-all cursor-pointer">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="w-10 h-10 rounded-lg bg-cyan-500/20 flex items-center justify-center">
                      <Mail className="w-5 h-5 text-cyan-400" />
                    </div>
                    <h4 className="text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      Email Support
                    </h4>
                  </div>
                  <p className="text-sm text-gray-400 ml-13">
                    support@supralottery.com
                  </p>
                  <p className="text-xs text-gray-500 ml-13 mt-1">
                    Response within 24 hours
                  </p>
                </div>

                <div className="glass p-4 rounded-xl hover:bg-white/10 transition-all cursor-pointer">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="w-10 h-10 rounded-lg bg-purple-500/20 flex items-center justify-center">
                      <MessageCircle className="w-5 h-5 text-purple-400" />
                    </div>
                    <h4 className="text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      Live Chat
                    </h4>
                  </div>
                  <p className="text-sm text-gray-400 ml-13">
                    Available 24/7
                  </p>
                  <p className="text-xs text-gray-500 ml-13 mt-1">
                    Instant support
                  </p>
                </div>

                <div className="glass p-4 rounded-xl hover:bg-white/10 transition-all cursor-pointer">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="w-10 h-10 rounded-lg bg-pink-500/20 flex items-center justify-center">
                      <Book className="w-5 h-5 text-pink-400" />
                    </div>
                    <h4 className="text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      Documentation
                    </h4>
                  </div>
                  <p className="text-sm text-gray-400 ml-13">
                    Comprehensive guides
                  </p>
                  <p className="text-xs text-gray-500 ml-13 mt-1">
                    Self-service help
                  </p>
                </div>
              </div>
            </Card>

            {/* Quick Stats */}
            <Card className="glass-strong p-6 rounded-2xl border-purple-500/20">
              <h4 className="text-lg text-white mb-4" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Support Stats
              </h4>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-400">Avg Response Time</span>
                  <span className="text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>2 hours</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-400">Satisfaction Rate</span>
                  <span className="text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>98%</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-400">Tickets Resolved</span>
                  <span className="text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>5,000+</span>
                </div>
              </div>
            </Card>
          </div>

          {/* Contact Form */}
          <div className="lg:col-span-2">
            <Card className="glass-strong p-8 rounded-2xl border-purple-500/20">
              <h3 className="text-2xl text-white mb-6" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Send us a Message
              </h3>

              <form className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <Label className="text-gray-400 mb-2 block">Name</Label>
                    <Input
                      placeholder="Your name"
                      className="glass text-white border-gray-700 focus:border-cyan-400"
                    />
                  </div>
                  <div>
                    <Label className="text-gray-400 mb-2 block">Email</Label>
                    <Input
                      type="email"
                      placeholder="your@email.com"
                      className="glass text-white border-gray-700 focus:border-cyan-400"
                    />
                  </div>
                </div>

                <div>
                  <Label className="text-gray-400 mb-2 block">Subject</Label>
                  <Input
                    placeholder="How can we help?"
                    className="glass text-white border-gray-700 focus:border-cyan-400"
                  />
                </div>

                <div>
                  <Label className="text-gray-400 mb-2 block">Message</Label>
                  <Textarea
                    placeholder="Describe your issue or question..."
                    rows={6}
                    className="glass text-white border-gray-700 focus:border-cyan-400 resize-none"
                  />
                </div>

                <Button className="w-full bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white py-3 rounded-xl glow-cyan transition-all">
                  <Send className="w-4 h-4 mr-2" />
                  Send Message
                </Button>
              </form>
            </Card>
          </div>
        </div>

        {/* FAQ Section */}
        <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center">
              <HelpCircle className="w-6 h-6 text-white" />
            </div>
            <h3 className="text-3xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Frequently Asked Questions
            </h3>
          </div>

          <Accordion type="single" collapsible className="space-y-4">
            <AccordionItem value="item-1" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                How do I participate in a lottery draw?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                To participate, connect your wallet, navigate to the Dashboard, and click &quot;Buy Ticket&quot; on any active draw. Each ticket costs 100 SUPRA tokens. Once purchased, your ticket is automatically entered into the next draw.
              </AccordionContent>
            </AccordionItem>

            <AccordionItem value="item-2" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                How are winners selected?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                Winners are selected using a provably fair random number generator powered by Supra&rsquo;s VRF (Verifiable Random Function). All draws are transparent and verifiable on the blockchain, ensuring complete fairness.
              </AccordionContent>
            </AccordionItem>

            <AccordionItem value="item-3" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                When do I receive my winnings?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                Winnings are distributed automatically and instantly through smart contracts as soon as the draw is completed. The prize will be sent directly to your connected wallet address.
              </AccordionContent>
            </AccordionItem>

            <AccordionItem value="item-4" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                What happens if I lose my wallet access?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                Your tickets and any winnings are tied to your wallet address. Always keep your recovery phrase secure. If you lose access to your wallet, we cannot recover your funds as we don&rsquo;t have custody of your assets.
              </AccordionContent>
            </AccordionItem>

            <AccordionItem value="item-5" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                Can I verify the fairness of draws?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                Yes! Every draw result can be verified on the Supra blockchain. Navigate to the Draws section to view transaction hashes and verify the randomness of each draw independently.
              </AccordionContent>
            </AccordionItem>

            <AccordionItem value="item-6" className="glass rounded-xl border-purple-500/20 px-6">
              <AccordionTrigger className="text-white hover:text-cyan-400 transition-colors">
                What are the fees?
              </AccordionTrigger>
              <AccordionContent className="text-gray-400">
                Each ticket costs 100 SUPRA. There are no additional platform fees. A small portion goes to network gas fees, and the rest contributes to the prize pool.
              </AccordionContent>
            </AccordionItem>
          </Accordion>
        </Card>
      </div>
    </div>
  );
}

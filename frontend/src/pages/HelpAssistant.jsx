import { useState } from "react";
import { PaperPlaneTilt, Sparkle, UserCircle, WarningCircle } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const STARTER_QUESTIONS = [
  "How do I save a trip?",
  "How do I add an expense?",
  "How do I share a trip?",
  "How does Maps work?",
];

export default function HelpAssistant() {
  const [messages, setMessages] = useState([]);
  const [question, setQuestion] = useState("");
  const [asking, setAsking] = useState(false);
  const [error, setError] = useState("");

  const ask = async (value = question) => {
    const text = value.trim();
    if (!text || asking) return;
    setQuestion("");
    setError("");
    setMessages((current) => [...current, { role: "user", text }]);
    setAsking(true);
    try {
      const { data } = await api.post("/rag/ask", { question: text });
      setMessages((current) => [...current, { role: "assistant", text: data.answer, sources: data.sources || [] }]);
    } catch (e) {
      setError(fmtErr(e));
    } finally {
      setAsking(false);
    }
  };

  return (
    <div className="max-w-3xl" data-testid="help-assistant-page">
      <p className="label-overline mb-2">Travel OS Help</p>
      <h1 className="font-heading font-extrabold text-4xl sm:text-5xl tracking-tight mb-3">Ask how it works.</h1>
      <p className="text-muted-foreground mb-8">Answers come from the Travel OS help library. The assistant will say when the library does not have enough information.</p>

      {messages.length === 0 && (
        <div className="bg-white rounded-3xl shadow-soft p-6 mb-6" data-testid="help-starters">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-2xl bg-primary/10 text-primary flex items-center justify-center">
              <Sparkle size={21} weight="duotone" />
            </div>
            <div>
              <p className="font-heading font-bold">Travel Assistant</p>
              <p className="text-xs text-muted-foreground">Product help, grounded in Travel OS documentation</p>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {STARTER_QUESTIONS.map((starter) => (
              <button
                key={starter}
                type="button"
                onClick={() => ask(starter)}
                data-testid={`help-starter-${starter.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`}
                className="tap-scale rounded-full bg-secondary px-4 py-2 text-sm font-medium hover:bg-secondary/70"
              >
                {starter}
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="space-y-4 mb-6" data-testid="help-messages">
        {messages.map((message, index) => (
          <div key={`${message.role}-${index}`} className={`flex gap-3 ${message.role === "user" ? "justify-end" : "justify-start"}`}>
            {message.role === "assistant" && (
              <div className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0">
                <Sparkle size={18} weight="duotone" />
              </div>
            )}
            <div className={`max-w-[85%] rounded-3xl px-5 py-4 ${message.role === "user" ? "bg-primary text-white" : "bg-white shadow-soft"}`}>
              <p className="text-sm leading-relaxed whitespace-pre-wrap">{message.text}</p>
              {message.sources?.length > 0 && (
                <div className="mt-3 pt-3 border-t border-border/70">
                  <p className="text-[10px] uppercase tracking-wider font-bold text-muted-foreground mb-1">Sources</p>
                  <p className="text-xs text-muted-foreground">{message.sources.map((source) => source.title).join(" · ")}</p>
                </div>
              )}
            </div>
            {message.role === "user" && (
              <div className="w-9 h-9 rounded-full bg-secondary text-muted-foreground flex items-center justify-center shrink-0">
                <UserCircle size={20} weight="duotone" />
              </div>
            )}
          </div>
        ))}
        {asking && (
          <div className="flex items-center gap-3" data-testid="help-loading">
            <div className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center"><Sparkle size={18} weight="duotone" className="animate-pulse" /></div>
            <div className="bg-white rounded-3xl shadow-soft px-5 py-4 text-sm text-muted-foreground">Checking the help library…</div>
          </div>
        )}
      </div>

      {error && (
        <div className="flex items-center gap-2 text-sm text-destructive font-medium mb-4" data-testid="help-error">
          <WarningCircle size={18} /> {error}
        </div>
      )}

      <form onSubmit={(event) => { event.preventDefault(); ask(); }} className="bg-white rounded-3xl shadow-soft p-3 flex gap-2" data-testid="help-form">
        <Input
          value={question}
          onChange={(event) => setQuestion(event.target.value)}
          placeholder="Ask about Travel OS…"
          maxLength={500}
          disabled={asking}
          data-testid="help-question-input"
          className="rounded-full h-12 px-5 border-0 shadow-none focus-visible:ring-0"
        />
        <Button type="submit" disabled={asking || !question.trim()} aria-label="Ask Travel OS Help" data-testid="help-submit-button" className="rounded-full bg-primary text-white h-12 w-12 p-0 shrink-0 tap-scale">
          <PaperPlaneTilt size={19} weight="fill" />
        </Button>
      </form>
    </div>
  );
}

--[[

Syncronization extension for VLC -- client component
Copyright (c) 2011 Joshua Watzman (sinclair44@gmail.com)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.

--]]

-- set to false to tell TODO
enabled = true

function dlog(msg)
	vlc.msg.dbg(string.format("[sync-client] %s", msg))
end

function descriptor()
	return
	{
		title = "Sync Client";
		version = "2011-01-24";
		author = "jwatzman";
		shortdesc = "Sync Client";
		description = "Synchronizes two viewings of the same video over the "
		           .. "internet. This is the client component -- we connect "
		           .. "to the server and it tells us how far into the video "
		           .. "we should be.";
		capabilities = { "input-listener", "playing-listener" };
	}
end

function client(fd)
	while enabled do
		local pollfds = {}
		pollfds[fd] = vlc.net.POLLIN

		local input = vlc.object.input()
		if not input then
			enabled = false
			vlc.deactivate()
		elseif vlc.net.poll(pollfds, 1) > 0 then
			local str = vlc.net.recv(fd, 1000)
			if str == "" or str == "\004" then
				enabled = false
				vlc.deactivate()
			else
				vlc.keep_alive()
				local i, j = string.find(str, "%d+\n")
				local remote_time = tonumber(string.sub(str, i, j))
				local local_time = math.floor(1000 * vlc.var.get(input, "time"))

				if math.abs(remote_time - local_time) > tonumber(jitter) then
					dlog(string.format("updating time from %i to %i",
						local_time, remote_time))
					vlc.var.set(input, "time", remote_time/1000)
				end
			end
		end
	end
	vlc.net.close(fd)
end

function update_params()
	server = server_w:get_text()
	jitter = jitter_w:get_text()
	vlc.msg.info(server)
	vlc.msg.info(jitter)
	conf_d:delete()

	local fd = vlc.net.connect_tcp("localhost", 1234)

	if fd < 0 then
		dlog("connect_tcp failed")
		local dialog = vlc.dialog("Sync Client")
		dialog:add_label("Connection failed.", 1, 1, 1, 1)
		dialog:add_button("Close", vlc.deactivate, 2, 1, 1, 1)
		dialog:show()
	else	
		client(fd)
	end
end

function set_params()
	conf_d = vlc.dialog("Sync Client")
	conf_d:add_label("Connect to:", 1, 1, 1, 1)
	conf_d:add_label("Jitter tolerance (ms):", 1, 2, 1, 1)
	server_w = conf_d:add_text_input("localhost", 2, 1, 1, 1)
	jitter_w = conf_d:add_text_input("250", 2, 2, 1, 1)
	conf_d:add_button("OK", update_params, 3, 1, 1, 1)
	conf_d:show()
end

function activate()
	dlog("activated")
	enabled = true

	if not vlc.input.is_playing() then
		dlog("not playing")
		local dialog = vlc.dialog("Sync Client")
		dialog:add_label("Nothing is playing!", 1, 1, 1, 1)
		dialog:add_button("Close", vlc.deactivate, 2, 1, 1, 1)
		dialog:show()
	else
		set_params()
	end
end

function deactivate()
	dlog("deactivated")
	enabled = false
end

function input_changed()
	dlog("input changed")
	vlc.deactivate()
end

function status_changed()
	dlog("status changed")
	vlc.deactivate()
end

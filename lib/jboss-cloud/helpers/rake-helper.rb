# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

module JBossCloud
  def self.default_task?
    Rake.application.top_level_tasks.include?("default")
  end

  def self.validation_task?
    return false if Rake.application.top_level_tasks.include?("default")
    Rake.application.top_level_tasks.each do |task|
      return true if task.match(/^validate:/)
    end
    false
  end

  def self.building_task?
    Rake.application.top_level_tasks.each do |task|
      return true if (task.match(/^appliance:/) or task.match(/^rpm:/)) and !task.match(/^rpm:sign/) and !task.match(/^rpm:upload/)
    end
    false
  end
end